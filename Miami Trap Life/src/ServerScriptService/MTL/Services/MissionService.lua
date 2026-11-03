--!strict
-- Runs missions step by step (Config/Missions.<Id>.Steps). The server owns every step: it sets the one "Story"
-- waypoint, checks distances, hold times and aim (anti-exploit), and tells the client what to show (MissionState).
-- Piece 3 ships one mission, FirstMission (rob Liberty Food Mart); the runner is generic for later story missions.
--
-- API (Master Plan §3.5):
--   MissionService.start(player, missionId)        teleports to the start, gives the mission gun, step 1
--   MissionService.stop(player, reason?)           abandon (no reward); cleans up mask / bag / gun
--   MissionService.cleanup(player)                 remove mission gear (mask, cash bag, temporary gun)
--   MissionService.active(player) -> missionId?
--   MissionService.point(missionId, name) -> (CFrame, radius)   resolved spot (map part wins over config)
--   MissionService.send(player, payload)           a MissionState message (StoryCrew: payout, meet...)
--   MissionService.onAction(type, fn(player, payload))  extra MissionAction types (StoryCrew: closeOffer, buy)
--   MissionService.Completed: Signal(player, missionId, result = { seconds, escapeSeconds, clean })
--   MissionService.StepDone: Signal(player, missionId, stepId)
-- Guns (optional, Guns thread): GunService.give/take/equip + Intimidating/Fired signals. Without GunService the aim
-- step falls back to a built-in hold-aim the server validates (distance + facing + hold time).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

local Net = require(ReplicatedStorage.MTL.Net)
local Signal = require(ReplicatedStorage.MTL.Signal)
local Missions = require(ReplicatedStorage.MTL.Config.Missions)
local Locations = require(ReplicatedStorage.MTL.Config.Locations)
local MissionRules = require(ReplicatedStorage.MTL.Rules.MissionRules)
local Rig = require(ReplicatedStorage.MTL.Rig)
local WaypointService = require(script.Parent.WaypointService)
local Notify = require(script.Parent.Notify)
local Analytics = require(script.Parent.Analytics)
local RateLimiter = require(script.Parent.RateLimiter)
local CutsceneService = require(script.Parent.CutsceneService)

local MissionService = {}
MissionService.Completed = Signal.new() -- (player, missionId, result)
MissionService.StepDone = Signal.new() -- (player, missionId, stepId)

type Run = {
	id: string,
	def: any,
	index: number,
	startedAt: number,
	stepAt: number,
	begunAt: number?,
	alarmAt: number?,
	session: string,
	token: number,
	lastProgress: number,
	finishing: boolean,
}

local runs: { [Player]: Run } = {}
local handlers: { [string]: (Player, any) -> () } = {}
local limiter = RateLimiter.new(6, 10)
local tokenCounter = 0
local WAYPOINT = "Story" -- the one main waypoint (Research: Onboarding Funnels)
local POINT_FOLDER = "MTL_Stations" -- Workspace.MTL_Stations.<MissionId>.<Point> parts override config spots

local function log(...)
	print("[MTL Mission]", ...)
end

local function now(): number
	return os.clock()
end

local function root(player: Player): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

---------------------------------------------------------------- optional GunService (Guns thread)

local gunsCache: any = false
local function guns(): any?
	if gunsCache ~= false then
		return gunsCache
	end
	local m = script.Parent:FindFirstChild("GunService")
	if not m then
		return nil -- not installed yet: check again next time
	end
	local ok, g = pcall(require, m)
	gunsCache = if ok and type(g) == "table" then g else nil
	return gunsCache
end

local function gunCall(name: string, ...: any): any
	local g = guns()
	local fn = g and g[name]
	if type(fn) ~= "function" then
		return nil
	end
	local ok, res = pcall(fn, ...)
	if not ok then
		warn("[MTL Mission] GunService." .. name, "failed:", res)
		return nil
	end
	return res
end

---------------------------------------------------------------- points

local pointCache: { [string]: { [string]: { cf: CFrame, radius: number } } } = {}

local function floorAt(pos: Vector3): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ex: { Instance } = {}
	local stations = workspace:FindFirstChild(POINT_FOLDER)
	if stations then
		table.insert(ex, stations)
	end
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ex, p.Character)
		end
	end
	-- first solid, visible thing below (walk-through volumes and invisible parts don't count)
	local function solid(origin: Vector3): RaycastResult?
		for _ = 1, 8 do
			params.FilterDescendantsInstances = ex
			local h = workspace:Raycast(origin, Vector3.new(0, -40, 0), params)
			if not h then
				return nil
			end
			local part = h.Instance
			if not part:IsA("BasePart") or (part.CanCollide and part.Transparency < 0.95) then
				return h
			end
			table.insert(ex, part)
		end
		return nil
	end
	-- skip overhangs (an awning, a canopy, a sign): a surface with 5+ studs of open space under it, down to the
	-- next solid surface, is something you stand UNDER, not on. The Food Mart awning used to catch the door point.
	local hit = solid(pos + Vector3.new(0, 6, 0))
	for _ = 1, 4 do
		if not hit then
			break
		end
		table.insert(ex, hit.Instance)
		local below = solid(hit.Position - Vector3.new(0, 0.05, 0))
		if below and hit.Position.Y - below.Position.Y >= 5 then
			hit = below
		else
			break
		end
	end
	return if hit then hit.Position.Y else pos.Y - 1
end

function MissionService.point(missionId: string, name: string): (CFrame, number)
	local cache = pointCache[missionId]
	if cache and cache[name] then
		return cache[name].cf, cache[name].radius
	end
	local def = (Missions :: any)[missionId]
	local cfg = def.Points[name]
	local cf: CFrame
	local radius = cfg.radius or 8
	local folder = workspace:FindFirstChild(POINT_FOLDER)
	local mf = folder and folder:FindFirstChild(missionId)
	local part = mf and mf:FindFirstChild(name)
	if part and part:IsA("BasePart") then
		local p = part.Position
		cf = CFrame.new(p.X, floorAt(p), p.Z) * part.CFrame.Rotation
		local r = part:GetAttribute("Radius")
		if type(r) == "number" then
			radius = r
		end
	else
		local base = Locations.FoodMart.Inside
		local p = base + (cfg.offset or Vector3.zero)
		cf = CFrame.new(p.X, floorAt(p), p.Z) * CFrame.Angles(0, math.rad(cfg.yaw or 0), 0)
	end
	pointCache[missionId] = cache or {}
	pointCache[missionId][name] = { cf = cf, radius = radius }
	return cf, radius
end

---------------------------------------------------------------- client messages

function MissionService.send(player: Player, payload: { [string]: any })
	Net.get("MissionState"):FireClient(player, payload)
end

local function bark(player: Player, line: { string }?)
	if line then
		MissionService.send(player, { type = "bark", who = line[1], text = line[2] })
	end
end

local function sendState(player: Player)
	local run = runs[player]
	if not run then
		MissionService.send(player, { type = "clear" })
		return
	end
	local def = run.def
	local step = def.Steps[run.index]
	local pcf, radius = MissionService.point(run.id, step.point)
	local car = MissionService.point(run.id, "Car")
	MissionService.send(player, {
		type = "state",
		mission = run.id,
		title = def.Title,
		index = run.index,
		steps = MissionRules.checklist(def, run.index),
		step = {
			id = step.id,
			kind = step.kind,
			text = step.text,
			verb = step.verb,
			seconds = step.seconds,
			pos = pcf.Position,
			radius = radius,
		},
		car = car,
		clerk = MissionService.point(run.id, "Clerk").Position,
		register = MissionService.point(run.id, "Register").Position,
		alarm = run.alarmAt ~= nil,
		alarmFor = if run.alarmAt then now() - run.alarmAt else nil,
		cleanSeconds = if def.CleanGetaway then def.CleanGetaway.Seconds else nil,
		aimFallback = guns() == nil or guns().Intimidating == nil,
	})
end

---------------------------------------------------------------- gear (mask, cash bag) on the real character

local function headOf(char: Model): BasePart?
	return char:FindFirstChild("Head") :: BasePart?
end

local function weldTo(part: BasePart, to: BasePart, offset: CFrame)
	part.CFrame = to.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = to
	w.Part1 = part
	w.Parent = part
end

local function putMask(player: Player)
	local char = player.Character
	local head = char and headOf(char)
	if not char or not head or char:FindFirstChild("MTL_Mask") then
		return
	end
	local lib = ReplicatedStorage:FindFirstChild("MTL_Actors")
	local acc = lib and lib:FindFirstChild("Mask") -- TODO(Alex art): an Accessory named Mask here replaces the placeholder
	local hum = char:FindFirstChildOfClass("Humanoid")
	if acc and acc:IsA("Accessory") and hum then
		-- hair and hats would poke through a fitted ski mask: hide them while it's on (cleanup puts them back)
		for _, x in char:GetChildren() do
			local h = x:IsA("Accessory") and x:FindFirstChild("Handle")
			if h and h:IsA("BasePart") and (x.AccessoryType == Enum.AccessoryType.Hair or x.AccessoryType == Enum.AccessoryType.Hat
				or x.AccessoryType == Enum.AccessoryType.Face or x.AccessoryType == Enum.AccessoryType.Unknown and (h.Position - head.Position).Magnitude < 2.2) then
				h:SetAttribute("MTL_MaskHid", h.Transparency)
				h.Transparency = 1
			end
		end
		local a = acc:Clone()
		a.Name = "MTL_Mask"
		hum:AddAccessory(a)
		return
	end
	local m = Instance.new("Part")
	m.Name = "MTL_Mask"
	m.Size = head.Size * Vector3.new(1.08, 1.06, 1.08)
	m.Color = Color3.fromRGB(18, 18, 20)
	m.Material = Enum.Material.Fabric
	m.CanCollide = false
	m.CanQuery = false
	m.Massless = true
	for _, x in { -0.22, 0.22 } do
		local eye = Instance.new("Part")
		eye.Name = "EyeHole"
		eye.Size = Vector3.new(0.28, 0.16, 0.05)
		eye.Color = Color3.fromRGB(235, 235, 240)
		eye.CanCollide = false
		eye.CanQuery = false
		eye.Massless = true
		eye.Parent = m
		weldTo(eye, head, CFrame.new(x * head.Size.X, 0.1 * head.Size.Y, -head.Size.Z * 0.55))
	end
	m.Parent = char
	weldTo(m, head, CFrame.new())
end

local function putBag(player: Player)
	local char = player.Character
	if not char or char:FindFirstChild("MTL_CashBag") then
		return
	end
	local torso = (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")) :: BasePart?
	if not torso then
		return
	end
	-- the real duffel (ReplicatedStorage.MTL_Actors.CashBag, pivot = its centre), slung across the back
	local lib = ReplicatedStorage:FindFirstChild("MTL_Actors")
	local template = lib and lib:FindFirstChild("CashBag")
	if template and template:IsA("Model") then
		local m = template:Clone()
		m.Name = "MTL_CashBag"
		local _, size = m:GetBoundingBox()
		m:PivotTo(torso.CFrame * CFrame.new(0, -0.15, torso.Size.Z / 2 + size.Z / 2 - 0.05) * CFrame.Angles(0, 0, math.rad(-18)))
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = false
				d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
				d.Massless = true
				local w = Instance.new("WeldConstraint")
				w.Part0 = torso
				w.Part1 = d
				w.Parent = d
			end
		end
		m.Parent = char
		return
	end
	local bag = Instance.new("Part")
	bag.Name = "MTL_CashBag"
	bag.Size = Vector3.new(1.6, 1.8, 0.9)
	bag.Color = Color3.fromRGB(40, 70, 50)
	bag.Material = Enum.Material.Fabric
	bag.CanCollide = false
	bag.CanQuery = false
	bag.Massless = true
	bag.Parent = char
	weldTo(bag, torso, CFrame.new(0, -0.1, torso.Size.Z / 2 + 0.45))
end

-- a looping body action on the character (ActionPose on every client), e.g. "Grab" while stuffing the bag
local actionToken: { [Player]: number } = {}
local function setAction(player: Player, name: string?, seconds: number?)
	actionToken[player] = (actionToken[player] or 0) + 1
	local char = player.Character
	if char then
		char:SetAttribute("MTL_Action", name)
	end
	if name then
		local token = actionToken[player]
		task.delay((seconds or 3) + 2, function()
			local c = player.Character
			if actionToken[player] == token and c then
				c:SetAttribute("MTL_Action", nil)
			end
		end)
	end
end

function MissionService.cleanup(player: Player)
	setAction(player, nil)
	local char = player.Character
	if char then
		for _, n in { "MTL_Mask", "MTL_CashBag" } do
			local g = char:FindFirstChild(n)
			if g then
				g:Destroy()
			end
		end
		for _, d in char:GetDescendants() do
			local t = d:GetAttribute("MTL_MaskHid")
			if type(t) == "number" and d:IsA("BasePart") then
				d.Transparency = t
				d:SetAttribute("MTL_MaskHid", nil)
			end
		end
	end
	local run = runs[player]
	local gun = if run and run.def.Gun then run.def.Gun.Id else Missions.FirstMission.Gun.Id
	gunCall("take", player, gun)
end

---------------------------------------------------------------- the clerk (one shared server NPC while anyone robs)

local clerk: Model? = nil
local clerkJoints: Rig.Joints? = nil
local clerkScared = false
local clerkSpawning = false

local function anyRun(id: string): boolean
	for _, r in runs do
		if r.id == id then
			return true
		end
	end
	return false
end

local function spawnClerk(missionId: string)
	if clerk or clerkSpawning then
		return
	end
	clerkSpawning = true
	local def = (Missions :: any)[missionId]
	local m = CutsceneService.rig(def.Clerk)
	clerkSpawning = false
	if not m or not anyRun(missionId) then
		if m then
			m:Destroy()
		end
		return
	end
	local cf = MissionService.point(missionId, "Clerk")
	local r = m:FindFirstChild("HumanoidRootPart") :: BasePart
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = d == r
			d.CanCollide = false
			d.Massless = true
		end
	end
	m.Name = "MTL_Clerk"
	m:SetAttribute("MTL_Mission", missionId)
	CollectionService:AddTag(m, "MTL_Intimidate")
	m.PrimaryPart = r
	r.CFrame = cf + Vector3.new(0, Rig.rootHeight(m), 0)
	m.Parent = workspace
	clerk = m
	clerkJoints = Rig.joints(m)
	clerkScared = false
end

local function scareClerk(player: Player)
	if not clerk or not clerkJoints then
		return
	end
	if not clerkScared then
		clerkScared = true
		Rig.apply(clerkJoints, Rig.compose({ pose = "HandsUp", poseT0 = -10, breath = false }, 0), "C0")
	end
	-- face whoever is robbing
	local r = clerk.PrimaryPart
	local pr = root(player)
	if r and pr then
		local p = r.Position
		local look = Vector3.new(pr.Position.X, p.Y, pr.Position.Z)
		if (look - p).Magnitude > 0.5 then
			r.CFrame = CFrame.lookAt(p, look)
		end
	end
end

local function calmClerk()
	if clerk and clerkJoints and clerkScared then
		clerkScared = false
		Rig.reset(clerkJoints, "C0")
	end
end

local function refreshClerk(missionId: string)
	if not anyRun(missionId) then
		if clerk then
			clerk:Destroy()
			clerk, clerkJoints, clerkScared = nil, nil, false
		end
		return
	end
	-- nobody past the threat any more -> calm again
	local threatened = false
	for _, r in runs do
		local s = r.def.Steps[r.index]
		local ti = MissionRules.stepIndex(r.def, "Threaten") or math.huge
		if r.id == missionId and s and r.index > ti then
			threatened = true
		end
	end
	if not threatened then
		calmClerk()
	end
end

---------------------------------------------------------------- steps

local function teleportToStart(player: Player, run: Run)
	local car = MissionService.point(run.id, "Car")
	local r = root(player)
	if r then
		-- behind the car (its +Z side), facing it: the mask box is in the trunk
		local spot = car * CFrame.new(0, 0, 9.5)
		local pos = spot.Position + Vector3.new(0, 3, 0)
		r.CFrame = CFrame.lookAt(pos, pos + car.LookVector)
		r.AssemblyLinearVelocity = Vector3.zero
	end
end

local enterStep: (Player, Run) -> ()

local function completeStep(player: Player, run: Run)
	setAction(player, nil)
	local def = run.def
	local step = def.Steps[run.index]
	log(player.Name, run.id, "step done:", step.id)
	Analytics.funnel(player, run.id, run.session, run.index + 1, step.id)
	MissionService.StepDone:Fire(player, run.id, step.id)
	-- side effects of finishing a step
	if step.id == "Mask" then
		putMask(player)
	elseif step.kind == "aim" then
		scareClerk(player)
		bark(player, step.after)
	elseif step.id == "Grab" then
		putBag(player)
	end
	if MissionRules.isLast(def, run.index) then
		run.finishing = true
		WaypointService.clear(player, WAYPOINT)
		local escape = if run.alarmAt then now() - run.alarmAt else nil
		local take, bonus, clean = MissionRules.payout(def, escape)
		local result = { seconds = now() - run.startedAt, escapeSeconds = escape, clean = clean, take = take, bonus = bonus }
		runs[player] = nil
		MissionService.send(player, { type = "clear", reason = "done" })
		refreshClerk(run.id)
		log(player.Name, run.id, "complete in", math.floor(result.seconds), "s")
		MissionService.Completed:Fire(player, run.id, result)
		return
	end
	run.index += 1
	enterStep(player, run)
end

enterStep = function(player: Player, run: Run)
	local def = run.def
	local step = def.Steps[run.index]
	run.stepAt = now()
	run.begunAt = nil
	run.lastProgress = 0
	if step.alarm and not run.alarmAt then
		run.alarmAt = now()
	end
	local pcf, radius = MissionService.point(run.id, step.point)
	-- zone steps finish on arrival; hold/aim steps use the waypoint only to guide (arrival just clears the marker)
	WaypointService.set(player, WAYPOINT, pcf.Position, {
		label = step.text,
		radius = if step.kind == "zone" then radius else math.min(radius, 6),
		breadcrumbs = true,
	})
	Notify.objective(player, step.text)
	if step.kind == "aim" then
		gunCall("equip", player, def.Gun.Id)
	end
	bark(player, step.bark)
	sendState(player)
end

function MissionService.active(player: Player): string?
	local r = runs[player]
	return r and r.id
end

local wired = false
local function wireGuns()
	if wired then
		return
	end
	local g = guns()
	if not g then
		return
	end
	wired = true
	if g.Intimidating and g.Intimidating.Connect then
		g.Intimidating:Connect(function(player: Player, target: Instance?, held: number)
			local run = runs[player]
			if not run or run.finishing then
				return
			end
			local step = run.def.Steps[run.index]
			if step.kind ~= "aim" or not target or target:GetAttribute("MTL_Mission") ~= run.id then
				return
			end
			local value = math.clamp((held or 0) / step.seconds, 0, 1)
			if math.abs(value - run.lastProgress) >= 0.05 or value >= 1 then
				run.lastProgress = value
				MissionService.send(player, { type = "progress", value = value })
			end
			if held >= step.seconds then
				completeStep(player, run)
			end
		end)
	end
	if g.Fired and g.Fired.Connect then
		-- a shot during the stick-up scares the clerk straight away (intimidate guns deal no damage)
		g.Fired:Connect(function(player: Player)
			local run = runs[player]
			if run and not run.finishing and run.def.Steps[run.index].kind == "aim" then
				local r = root(player)
				local cpos = MissionService.point(run.id, "Clerk").Position
				if r and (r.Position - cpos).Magnitude <= run.def.AimRange then
					completeStep(player, run)
				end
			end
		end)
	end
end

function MissionService.start(player: Player, missionId: string)
	local def = (Missions :: any)[missionId]
	assert(def and def.Steps, "[MTL Mission] unknown mission " .. tostring(missionId))
	if runs[player] then
		return
	end
	wireGuns()
	-- no shift during a mission
	local jm = script.Parent:FindFirstChild("JobService")
	if jm then
		local ok, js = pcall(require, jm)
		if ok and js.isOnShift and js.isOnShift(player) then
			js.clockOut(player, "story")
		end
	end
	tokenCounter += 1
	local run: Run = {
		id = missionId,
		def = def,
		index = 1,
		startedAt = now(),
		stepAt = now(),
		begunAt = nil,
		alarmAt = nil,
		session = HttpService:GenerateGUID(false),
		token = tokenCounter,
		lastProgress = 0,
		finishing = false,
	}
	runs[player] = run
	local car = MissionService.point(missionId, "Car")
	pcall(function()
		player:RequestStreamAroundAsync(car.Position, 5)
	end)
	if runs[player] ~= run then
		return
	end
	teleportToStart(player, run)
	if def.Gun then
		gunCall("give", player, def.Gun.Id, { temporary = true, mode = "Intimidate", ammo = def.Gun.Ammo })
	end
	task.spawn(spawnClerk, missionId)
	Analytics.funnel(player, missionId, run.session, 1, "Start")
	log(player.Name, "start", missionId)
	enterStep(player, run)
end

-- Back to step 1 at the car (after dying or wandering off). No penalty: the crew just pulls you back.
local function restart(player: Player, why: string)
	local run = runs[player]
	if not run or run.finishing then
		return
	end
	MissionService.cleanup(player)
	run.index = 1
	run.alarmAt = nil
	run.startedAt = now()
	teleportToStart(player, run)
	if run.def.Gun then
		gunCall("give", player, run.def.Gun.Id, { temporary = true, mode = "Intimidate", ammo = run.def.Gun.Ammo })
	end
	Notify.toast(player, why)
	refreshClerk(run.id)
	enterStep(player, run)
end

function MissionService.stop(player: Player, reason: string?)
	local run = runs[player]
	if not run then
		return
	end
	MissionService.cleanup(player)
	runs[player] = nil
	WaypointService.clear(player, WAYPOINT)
	MissionService.send(player, { type = "clear", reason = reason or "stopped" })
	refreshClerk(run.id)
	log(player.Name, "stopped", run.id, reason or "")
end

function MissionService.onAction(actionType: string, fn: (Player, any) -> ())
	handlers[actionType] = fn
end

---------------------------------------------------------------- client actions

local function onAction(player: Player, payload: any)
	if type(payload) ~= "table" or type(payload.type) ~= "string" then
		return
	end
	local custom = handlers[payload.type]
	if custom then
		custom(player, payload)
		return
	end
	local run = runs[player]
	if not run or run.finishing then
		return
	end
	local def = run.def
	local step = def.Steps[run.index]
	if payload.step ~= step.id then
		return
	end
	local r = root(player)
	if not r then
		return
	end
	local pcf, radius = MissionService.point(run.id, step.point)
	local flatDist = Vector2.new(r.Position.X - pcf.Position.X, r.Position.Z - pcf.Position.Z).Magnitude
	if step.kind == "hold" then
		if flatDist > radius + 4 then
			return
		end
		if payload.type == "begin" then
			run.begunAt = now()
			if step.id == "Grab" then
				setAction(player, "Grab", step.seconds) -- both hands into the drawer, cash into the bag
			end
		elseif payload.type == "step" and run.begunAt then
			if MissionRules.holdOk(step.seconds, now() - run.begunAt, def.MinHoldShare) then
				completeStep(player, run)
			else
				run.begunAt = nil
				setAction(player, nil)
			end
		end
	elseif step.kind == "aim" then
		-- built-in aim (only when GunService doesn't drive this step)
		local g = guns()
		if g and g.Intimidating then
			return
		end
		local look = r.CFrame.LookVector
		local ok = MissionRules.facingOk(r.Position.X, r.Position.Z, look.X, look.Z, pcf.Position.X, pcf.Position.Z, def.AimDot, def.AimRange)
		if payload.type == "begin" then
			run.begunAt = if ok then now() else nil
		elseif payload.type == "step" and run.begunAt then
			if ok and MissionRules.holdOk(step.seconds, now() - run.begunAt, def.MinHoldShare) then
				completeStep(player, run)
			else
				run.begunAt = nil
			end
		end
	end
end

function MissionService.init()
	Net.get("MissionAction").OnServerEvent:Connect(function(player, payload)
		if not limiter:allow(player) then
			return
		end
		local ok, err = pcall(onAction, player, payload)
		if not ok then
			warn("[MTL Mission] action failed:", err)
		end
	end)

	-- zone steps: the server-checked waypoint arrival
	WaypointService.Arrived:Connect(function(player, id)
		local run = runs[player]
		if id ~= WAYPOINT or not run or run.finishing then
			return
		end
		local step = run.def.Steps[run.index]
		if step.kind == "zone" then
			completeStep(player, run)
		end
	end)

	Net.get("ClientReady").OnServerEvent:Connect(function(player)
		if runs[player] then
			sendState(player)
		end
	end)

	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			if runs[player] then
				task.wait(0.6)
				restart(player, "The crew got you back to the car. Run it again.")
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		local run = runs[player]
		runs[player] = nil
		if run then
			refreshClerk(run.id)
		end
	end)

	-- wandering far from the job: back to the car (never a fail screen)
	task.spawn(function()
		while true do
			task.wait(1)
			for player, run in runs do
				local r = root(player)
				local def = run.def
				if r and def.ResetRadius and not run.finishing then
					local d = (r.Position - Locations.FoodMart.Inside).Magnitude
					if d > def.ResetRadius then
						task.spawn(restart, player, "Too far from the job. The crew picked you up.")
					end
				end
				-- keep the clerk facing the robber while the robbery is on
				if clerkScared and run.index > (MissionRules.stepIndex(def, "Threaten") or math.huge) then
					scareClerk(player)
				end
			end
		end
	end)
	log("ready")
end

-- Studio test (server Command Bar): _G.MTL.Missions.debugStep(player) completes the current step.
function MissionService.debugStep(player: Player)
	assert(game:GetService("RunService"):IsStudio(), "[MTL Mission] debugStep is Studio-only")
	local run = runs[player]
	if run then
		completeStep(player, run)
	end
end

return MissionService
