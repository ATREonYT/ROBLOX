--!strict
-- Heat stars (0-5) and NPC police (Config/Crime.Heat + Crime.Police). Research §5 P0-2.
--   * Heat only goes up from a crime the server knows about (CrimeService calls raise) or from shooting at / near
--     the police. It never starts randomly, so an innocent player is never chased.
--   * Losing heat: stay out of every police unit's sight for Heat.LoseSeconds[stars] and you drop a star; hide in
--     your own flat and it's gone in a few seconds. Going down clears it.
--   * Units: a cruiser per star (Police.UnitsPerStar) spawns on a road out of sight, drives the street graph
--     (Rules/RoadGraph over ReplicatedStorage.MTL_RoadMap) to the road nearest you, and two officers get out and run
--     at you. From 2 stars they shoot (Police.ShootFrom). An officer close to you while you're slow cuffs you:
--     BOOKED. Busted = lose your dirty cash (CrimeService decides, through PoliceService.onBust), never clean money,
--     guns or cars.
--   * Cars move with AlignPosition/AlignOrientation on an unanchored body, so clients see them glide (physics
--     replication interpolates) instead of stepping at the network rate. No collisions on the car (nothing to snag).
--
-- API:
--   PoliceService.heat(player) -> stars
--   PoliceService.raise(player, stars, reason)       -- crime happened: stars = max(current, stars); resets "unseen"
--   PoliceService.clear(player, reason?)             -- 0 stars, units leave
--   PoliceService.onBust = fn(player) -> lostDirty   -- set by CrimeService
--   PoliceService.HeatChanged: Signal(player, stars, old)   PoliceService.Busted: Signal(player)
--   Player attribute MTL_Heat = stars (other players' clients show stars over your head).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Crime = require(ReplicatedStorage.MTL.Config.Crime)
local CrimeRules = require(ReplicatedStorage.MTL.Rules.CrimeRules)
local RoadGraph = require(ReplicatedStorage.MTL.Rules.RoadGraph)
local Net = require(ReplicatedStorage.MTL.Net)
local Signal = require(ReplicatedStorage.MTL.Signal)
local Notify = require(script.Parent.Notify)

local PoliceService = {}
PoliceService.HeatChanged = Signal.new() -- (player, stars, old)
PoliceService.Busted = Signal.new() -- (player)
PoliceService.onBust = nil :: ((Player) -> number)?

local H = Crime.Heat
local P = Crime.Police

type Officer = {
	model: Model,
	hum: Humanoid,
	root: BasePart,
	nextShot: number,
	cuff: number,
	stuck: number,
	lastPos: Vector3,
	runTrack: AnimationTrack?,
	idleTrack: AnimationTrack?,
}
type Unit = {
	id: number,
	target: Player?,
	car: Model,
	body: BasePart,
	align: AlignPosition,
	orient: AlignOrientation,
	path: { Vector3 },
	seg: number,
	pos: Vector3,
	look: Vector3,
	speed: number,
	routeAt: number,
	phase: string, -- "drive" | "foot" | "leave"
	officers: { Officer },
	leaveUntil: number,
	calmFor: number,
}
type HeatState = { stars: number, unseen: number, seenAt: number, homeFor: number, booked: boolean }

type Heli = { target: Player, model: Model, body: BasePart, align: AlignPosition, orient: AlignOrientation, angle: number, aim: BasePart, leaving: number? }

local units: { Unit } = {}
local helis: { [Player]: Heli } = {}
local heat: { [Player]: HeatState } = {}
local graph: RoadGraph.Graph? = nil
local rng = Random.new()
local unitCounter = 0
local folder: Folder

local function log(...)
	print("[MTL Police]", ...)
end

local function send(player: Player, payload: any)
	Net.get("CrimeState"):FireClient(player, payload)
end

local function root(player: Player): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function humanoid(player: Player): Humanoid?
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function state(player: Player): HeatState
	local s = heat[player]
	if not s then
		s = { stars = 0, unseen = 0, seenAt = 0, homeFor = 0, booked = false }
		heat[player] = s
	end
	return s
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

---------------------------------------------------------------- optional services (loaded lazily)

local function sibling(name: string): any?
	local m = script.Parent:FindFirstChild(name)
	if not m then
		return nil
	end
	local ok, svc = pcall(require, m)
	return if ok then svc else nil
end

---------------------------------------------------------------- heat

local function publish(player: Player, s: HeatState)
	player:SetAttribute(H.AttrName, s.stars)
	send(player, {
		type = "heat",
		stars = s.stars,
		unseen = s.unseen,
		lose = if s.stars > 0 then CrimeRules.loseSeconds(s.stars, H) else 0,
		seen = os.clock() - s.seenAt < 1.2,
	})
end

function PoliceService.heat(player: Player): number
	local s = heat[player]
	return if s then s.stars else 0
end

function PoliceService.raise(player: Player, stars: number, reason: string?)
	local s = state(player)
	if s.booked then
		return
	end
	local old = s.stars
	s.stars = CrimeRules.raise(s.stars, stars, H.Max)
	s.unseen = 0 -- a fresh crime: they know where you are
	s.seenAt = os.clock()
	if s.stars ~= old then
		log(player.Name, "heat", old, "->", s.stars, reason or "")
		PoliceService.HeatChanged:Fire(player, s.stars, old)
		if old == 0 then
			Notify.toast(player, "The police are on you. Break their line of sight to lose them.", Color3.fromRGB(120, 170, 255))
		end
	end
	publish(player, s)
end

function PoliceService.clear(player: Player, reason: string?)
	local s = state(player)
	local old = s.stars
	s.stars = 0
	s.unseen = 0
	if old ~= 0 then
		log(player.Name, "heat cleared", reason or "")
		PoliceService.HeatChanged:Fire(player, 0, old)
	end
	publish(player, s)
end

---------------------------------------------------------------- models

local function propsFolder(): Folder?
	return ServerStorage:FindFirstChild("MTL_CrimeProps") :: Folder?
end

-- Police cruiser: ServerStorage.MTL_CrimeProps.Cruiser (built by tools/BuildCrimeSites.lua from the map's sedan).
-- Fallback: a simple built cruiser.
local function buildCruiser(): Model
	local lib = propsFolder()
	local t = lib and lib:FindFirstChild("Cruiser")
	local m: Model
	if t and t:IsA("Model") then
		m = t:Clone()
	else
		m = Instance.new("Model")
		local function part(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?): Part
			local p = Instance.new("Part")
			p.Name = name
			p.Size = size
			p.CFrame = cf
			p.Color = color
			p.Material = mat or Enum.Material.SmoothPlastic
			p.Parent = m
			return p
		end
		local body = part("Body", Vector3.new(7, 2.4, 16), CFrame.new(0, 2.2, 0), Color3.fromRGB(18, 18, 22), Enum.Material.Metal)
		part("Doors", Vector3.new(7.05, 1.4, 7), CFrame.new(0, 2.3, 0), Color3.fromRGB(235, 235, 238), Enum.Material.Metal)
		part("Cabin", Vector3.new(6.4, 2, 8), CFrame.new(0, 4.3, 1), Color3.fromRGB(30, 34, 40), Enum.Material.Glass).Transparency = 0.25
		part("LightRed", Vector3.new(1.8, 0.45, 0.9), CFrame.new(-1.1, 5.55, 1), Color3.fromRGB(255, 40, 40), Enum.Material.Neon)
		part("LightBlue", Vector3.new(1.8, 0.45, 0.9), CFrame.new(1.1, 5.55, 1), Color3.fromRGB(40, 90, 255), Enum.Material.Neon)
		for _, x in { -3.1, 3.1 } do
			for _, z in { -5, 5 } do
				local w = part("Wheel", Vector3.new(1.2, 2.6, 2.6), CFrame.new(x, 1.3, z), Color3.fromRGB(20, 20, 20))
				w.Shape = Enum.PartType.Cylinder
			end
		end
		m.PrimaryPart = body
	end
	m.Name = "MTL_Cruiser"
	return m
end

local function setupCarPhysics(m: Model): (BasePart, AlignPosition, AlignOrientation)
	local body = m.PrimaryPart or m:FindFirstChild("Body", true) :: BasePart
	assert(body, "[MTL Police] cruiser has no body part")
	m.PrimaryPart = body
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = d == body
			d.Massless = d ~= body
			if d ~= body then
				local w = Instance.new("WeldConstraint")
				w.Part0 = body
				w.Part1 = d
				w.Parent = d
			end
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	local att = Instance.new("Attachment")
	att.Name = "Drive"
	att.Parent = body
	local ap = Instance.new("AlignPosition")
	ap.Mode = Enum.PositionAlignmentMode.OneAttachment
	ap.Attachment0 = att
	ap.RigidityEnabled = true
	ap.Parent = body
	local ao = Instance.new("AlignOrientation")
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.RigidityEnabled = true
	ao.Parent = body
	return body, ap, ao
end

-- one officer rig (R15 from a HumanoidDescription: navy uniform, badge, belt, cap, holstered pistol in hand)
local officerTemplate: Model? = nil
local function makeOfficerTemplate(): Model?
	local U = P.Uniform
	local desc = Instance.new("HumanoidDescription")
	local skin = U.Skin[1]
	desc.HeadColor, desc.LeftArmColor, desc.RightArmColor = skin, skin, skin
	desc.TorsoColor = U.Shirt
	desc.LeftLegColor, desc.RightLegColor = U.Pants, U.Pants
	if U.ShirtId ~= 0 then
		desc.Shirt = U.ShirtId
	end
	if U.PantsId ~= 0 then
		desc.Pants = U.PantsId
	end
	if U.HatId ~= "" then
		desc.HatAccessory = U.HatId
	end
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	desc:Destroy()
	if not ok or not model then
		warn("[MTL Police] couldn't build the officer rig:", model)
		return nil
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BaseScript") then
			d:Destroy()
		end
	end
	local function deco(name: string, parentName: string, size: Vector3, offset: CFrame, color: Color3, mat: Enum.Material?)
		local to = model:FindFirstChild(parentName) :: BasePart?
		if not to then
			return
		end
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = mat or Enum.Material.SmoothPlastic
		p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
		p.CFrame = to.CFrame * offset
		local w = Instance.new("WeldConstraint")
		w.Part0 = to
		w.Part1 = p
		w.Parent = p
		p.Parent = model
	end
	local navy = Color3.fromRGB(22, 28, 52)
	-- cap: crown + peak + gold badge
	deco("CapCrown", "Head", Vector3.new(1.32, 0.42, 1.32), CFrame.new(0, 0.62, 0.02), navy, Enum.Material.Fabric)
	deco("CapBand", "Head", Vector3.new(1.36, 0.16, 1.36), CFrame.new(0, 0.4, 0.02), Color3.fromRGB(10, 10, 12), Enum.Material.Fabric)
	deco("CapPeak", "Head", Vector3.new(1.0, 0.08, 0.55), CFrame.new(0, 0.36, -0.82) * CFrame.Angles(math.rad(-8), 0, 0), Color3.fromRGB(10, 10, 12))
	deco("CapBadge", "Head", Vector3.new(0.3, 0.26, 0.05), CFrame.new(0, 0.62, -0.68), Color3.fromRGB(230, 190, 80), Enum.Material.Metal)
	-- chest badge, shoulder radio, duty belt
	deco("Badge", "UpperTorso", Vector3.new(0.34, 0.4, 0.06), CFrame.new(-0.45, 0.3, -0.52), Color3.fromRGB(230, 190, 80), Enum.Material.Metal)
	deco("NameBar", "UpperTorso", Vector3.new(0.5, 0.12, 0.05), CFrame.new(0.45, 0.25, -0.52), Color3.fromRGB(200, 200, 200), Enum.Material.Metal)
	deco("Radio", "UpperTorso", Vector3.new(0.22, 0.4, 0.14), CFrame.new(0.62, 0.55, -0.45), Color3.fromRGB(15, 15, 15))
	deco("Belt", "LowerTorso", Vector3.new(2.06, 0.3, 1.1), CFrame.new(0, 0.05, 0), Color3.fromRGB(12, 12, 14), Enum.Material.Leather)
	deco("Holster", "LowerTorso", Vector3.new(0.3, 0.6, 0.5), CFrame.new(1.05, -0.2, 0), Color3.fromRGB(12, 12, 14), Enum.Material.Leather)
	-- sidearm in the right hand: the game's pistol model if there is one
	local guns = ReplicatedStorage:FindFirstChild("MTL_Assets") and ReplicatedStorage.MTL_Assets:FindFirstChild("Guns")
	local pistol = guns and guns:FindFirstChild("Pistol")
	local hand = model:FindFirstChild("RightHand") :: BasePart?
	if pistol and hand then
		local g = pistol:Clone()
		g.Name = "Sidearm"
		for _, d in g:GetDescendants() do
			if d:IsA("BaseScript") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.Massless = false, false, false, false, true
			end
		end
		local cf = if g:IsA("Model") then g:GetPivot() else (g :: any).CFrame
		local _ = cf
		if g:IsA("Model") then
			g:PivotTo(hand.CFrame * CFrame.new(0, -0.35, -0.45) * CFrame.Angles(math.rad(-90), 0, 0))
			for _, d in g:GetDescendants() do
				if d:IsA("BasePart") then
					local w = Instance.new("WeldConstraint")
					w.Part0 = hand
					w.Part1 = d
					w.Parent = d
				end
			end
		end
		g.Parent = model
	else
		deco("Sidearm", "RightHand", Vector3.new(0.22, 0.45, 1.0), CFrame.new(0, -0.35, -0.45), Color3.fromRGB(20, 20, 22), Enum.Material.Metal)
	end
	local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.DisplayWhenDamaged
	hum.MaxHealth = P.OfficerHealth
	hum.Health = P.OfficerHealth
	model.Name = "Officer"
	return model
end

local animIds = { Idle = 2510196951, Run = 913376220, Walk = 913402848 }
local function track(hum: Humanoid, id: number, looped: boolean): AnimationTrack?
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = hum
	end
	local a = Instance.new("Animation")
	a.AnimationId = "rbxassetid://" .. id
	local ok, t = pcall(function()
		return (animator :: Animator):LoadAnimation(a)
	end)
	if ok and t then
		t.Looped = looped
		return t
	end
	return nil
end

local function spawnOfficer(at: CFrame, stars: number): Officer?
	if not officerTemplate then
		officerTemplate = makeOfficerTemplate()
	end
	if not officerTemplate then
		return nil
	end
	local m = officerTemplate:Clone()
	-- a different face of the force each time
	local skin = P.Uniform.Skin[rng:NextInteger(1, #P.Uniform.Skin)]
	for _, n in { "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand" } do
		local p = m:FindFirstChild(n) :: BasePart?
		if p then
			p.Color = skin
		end
	end
	local bc = m:FindFirstChildOfClass("BodyColors")
	if bc then
		bc.HeadColor3, bc.LeftArmColor3, bc.RightArmColor3 = skin, skin, skin
	end
	local hum = m:FindFirstChildOfClass("Humanoid") :: Humanoid
	local r = m:FindFirstChild("HumanoidRootPart") :: BasePart
	hum.WalkSpeed = CrimeRules.perStar(P.OfficerSpeed, stars)
	-- officers pass through each other (otherwise a crowd of them climbs into a tower)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = "MTL_Officers"
		end
	end
	local swat = P.Swat
	if swat and stars >= swat.FromStars then
		-- SWAT: dark kit over the uniform, a helmet, more health
		for _, d in m:GetChildren() do
			if d:IsA("Shirt") or d:IsA("Pants") then
				d:Destroy()
			end
		end
		-- long sleeves and gloves too (the uniform is short-sleeved, so the arms would show skin)
		for _, n in { "UpperTorso", "LowerTorso", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand" } do
			local p = m:FindFirstChild(n) :: BasePart?
			if p then
				p.Color = swat.Kit
			end
		end
		local bcs = m:FindFirstChildOfClass("BodyColors")
		if bcs then
			bcs.TorsoColor3, bcs.LeftLegColor3, bcs.RightLegColor3 = swat.Kit, swat.Kit, swat.Kit
			bcs.LeftArmColor3, bcs.RightArmColor3 = swat.Kit, swat.Kit
		end
		local head = m:FindFirstChild("Head") :: BasePart?
		if head then
			for _, a in m:GetChildren() do
				if a:IsA("Accessory") then
					a:Destroy()
				end
			end
			local helmet = Instance.new("Part")
			helmet.Name = "Helmet"
			helmet.Shape = Enum.PartType.Ball
			helmet.Size = Vector3.new(1.45, 1.2, 1.45)
			helmet.Color = swat.Kit
			helmet.Material = Enum.Material.SmoothPlastic
			helmet.CanCollide, helmet.CanQuery, helmet.CanTouch, helmet.Massless = false, false, false, true
			helmet.CFrame = head.CFrame * CFrame.new(0, 0.3, 0.05)
			local w = Instance.new("WeldConstraint")
			w.Part0 = head
			w.Part1 = helmet
			w.Parent = helmet
			helmet.Parent = m
		end
		local torso = m:FindFirstChild("UpperTorso") :: BasePart?
		if torso then
			local vest = Instance.new("Part")
			vest.Name = "Vest"
			vest.Size = Vector3.new(2.1, 1.5, 1.25)
			vest.Color = Color3.fromRGB(40, 44, 50)
			vest.Material = Enum.Material.Fabric
			vest.CanCollide, vest.CanQuery, vest.CanTouch, vest.Massless = false, false, false, true
			vest.CFrame = torso.CFrame * CFrame.new(0, 0.1, 0)
			local w = Instance.new("WeldConstraint")
			w.Part0 = torso
			w.Part1 = vest
			w.Parent = vest
			local sg = Instance.new("SurfaceGui")
			sg.Face = Enum.NormalId.Back
			sg.CanvasSize = Vector2.new(200, 140)
			local t = Instance.new("TextLabel")
			t.Size = UDim2.fromScale(1, 1)
			t.BackgroundTransparency = 1
			t.Text = "SWAT"
			t.TextScaled = true
			t.Font = Enum.Font.GothamBlack
			t.TextColor3 = Color3.fromRGB(255, 220, 60)
			t.Parent = sg
			sg.Parent = vest
			vest.Parent = m
		end
		hum.MaxHealth = swat.Health
		hum.Health = swat.Health
		m:SetAttribute("Swat", true)
	end
	m:SetAttribute("MTL_Police", true)
	m:SetAttribute("MTL_Damageable", true)
	CollectionService:AddTag(m, "MTL_Officer")
	m:PivotTo(at + Vector3.new(0, 3, 0))
	m.Parent = folder
	pcall(function()
		r:SetNetworkOwner(nil)
	end)
	local o: Officer = {
		model = m,
		hum = hum,
		root = r,
		nextShot = os.clock() + 1.2,
		cuff = 0,
		stuck = 0,
		lastPos = r.Position,
		runTrack = track(hum, animIds.Run, true),
		idleTrack = track(hum, animIds.Idle, true),
	}
	if o.idleTrack then
		o.idleTrack:Play(0.2)
	end
	return o
end

---------------------------------------------------------------- road graph

local function ensureGraph()
	if graph then
		return
	end
	local mod = ReplicatedStorage:FindFirstChild("MTL_RoadMap")
	if not mod or not mod:IsA("ModuleScript") then
		warn("[MTL Police] no ReplicatedStorage.MTL_RoadMap: police cars will drive straight at you")
		return
	end
	local ok, data = pcall(require, mod)
	if ok and type(data) == "table" then
		graph = RoadGraph.build(data, 400)
		log("road graph ready:", #graph.nx, "cells")
	end
end

-- A road point between min and max studs from `around`, on the main street network.
local function spawnPoint(around: Vector3): (Vector3?, Vector3?)
	local g = graph
	if not g then
		local a = rng:NextNumber(0, math.pi * 2)
		local p = around + Vector3.new(math.cos(a), 0, math.sin(a)) * P.SpawnMin
		return p, (around - p).Unit
	end
	local best: number? = nil
	for _ = 1, 60 do
		local i = rng:NextInteger(1, #g.nx)
		if g.comp[i] == g.mainComp then
			local d = (Vector3.new(g.nx[i], 0, g.nz[i]) - flat(around)).Magnitude
			if d >= P.SpawnMin and d <= P.SpawnMax then
				best = i
				break
			end
		end
	end
	if not best then
		best = RoadGraph.nearest(g, around, 2000, g.mainComp)
	end
	if not best then
		return nil, nil
	end
	local p = Vector3.new(g.nx[best], g.ny[best], g.nz[best])
	local look = flat(around - p)
	return p, if look.Magnitude > 0.1 then look.Unit else Vector3.new(0, 0, -1)
end

local function routeTo(from: Vector3, to: Vector3): { Vector3 }
	local g = graph
	if g then
		local pts = RoadGraph.route(g, from, to)
		if pts and #pts >= 2 then
			-- keep the car on the road: drop the last straight leg to the target (it would cut through buildings)
			if #pts > 2 then
				table.remove(pts, #pts)
			end
			return pts
		end
	end
	return { from, to }
end

---------------------------------------------------------------- units

local function groundY(pos: Vector3, ignore: { Instance }): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(pos + Vector3.new(0, 12, 0), Vector3.new(0, -40, 0), params)
	return if hit then hit.Position.Y else pos.Y
end

local function placeCar(u: Unit)
	local look = if u.look.Magnitude > 0.01 then u.look else Vector3.new(0, 0, -1)
	local y = groundY(u.pos, { folder })
	local half = u.body.Size.Y / 2
	local ride = (u.car:GetAttribute("RideHeight") :: number?) or (half + 0.9)
	local cf = CFrame.lookAt(Vector3.new(u.pos.X, y + ride, u.pos.Z), Vector3.new(u.pos.X, y + ride, u.pos.Z) + look)
	u.align.Position = cf.Position
	u.orient.CFrame = cf.Rotation
end

local function dropOfficers(u: Unit)
	for _, o in u.officers do
		if o.model.Parent then
			o.model:Destroy()
		end
	end
	table.clear(u.officers)
end

local function setLeaving(u: Unit)
	if u.phase == "leave" then
		return
	end
	dropOfficers(u)
	u.phase = "leave"
	u.leaveUntil = os.clock() + 9
	-- drive off to a road point well away from everyone
	local away = u.pos + flat(u.pos - (if u.target and root(u.target) then (root(u.target) :: BasePart).Position else u.pos - u.look)).Unit * 300
	if away ~= away then
		away = u.pos + u.look * 300
	end
	u.path = routeTo(u.pos, away)
	u.seg = 1
	local siren = u.body:FindFirstChild("Siren", true)
	if siren and siren:IsA("Sound") then
		siren:Stop()
	end
	u.car:SetAttribute("Lights", false)
end

local function removeUnit(u: Unit)
	dropOfficers(u)
	if u.car.Parent then
		u.car:Destroy()
	end
	local i = table.find(units, u)
	if i then
		table.remove(units, i)
	end
end

local function spawnUnit(target: Player, stars: number): Unit?
	local r = root(target)
	if not r or #units >= P.MaxUnits then
		return nil
	end
	local at, look = spawnPoint(r.Position)
	if not at or not look then
		return nil
	end
	local car = buildCruiser()
	local body, ap, ao = setupCarPhysics(car)
	car:PivotTo(CFrame.lookAt(at + Vector3.new(0, 3, 0), at + Vector3.new(0, 3, 0) + look))
	CollectionService:AddTag(car, "MTL_PoliceCar")
	car:SetAttribute("MTL_Police", true)
	car:SetAttribute("Lights", true)
	local siren = Instance.new("Sound")
	siren.Name = "Siren"
	siren.SoundId = Crime.Sounds.Siren
	siren.Looped = true
	siren.Volume = 0.55
	siren.RollOffMode = Enum.RollOffMode.InverseTapered
	siren.RollOffMinDistance = 30
	siren.RollOffMaxDistance = 520
	siren.Parent = body
	car.Parent = folder
	pcall(function()
		body:SetNetworkOwner(nil)
	end)
	siren:Play()
	unitCounter += 1
	local u: Unit = {
		id = unitCounter,
		target = target,
		car = car,
		body = body,
		align = ap,
		orient = ao,
		path = routeTo(at, r.Position),
		seg = 1,
		pos = at,
		look = look,
		speed = CrimeRules.perStar(P.CarSpeed, stars),
		routeAt = os.clock(),
		phase = "drive",
		officers = {},
		leaveUntil = 0,
		calmFor = 0,
	}
	placeCar(u)
	table.insert(units, u)
	log("unit", u.id, "dispatched for", target.Name, "at", math.floor((at - r.Position).Magnitude), "studs")
	return u
end

local function unitsOn(player: Player): number
	local n = 0
	for _, u in units do
		if u.target == player and u.phase ~= "leave" then
			n += 1
		end
	end
	return n
end

---------------------------------------------------------------- sight

local sightParams = RaycastParams.new()
sightParams.FilterType = Enum.RaycastFilterType.Exclude

local function canSee(from: Vector3, player: Player, range: number, ignore: { Instance }): boolean
	local c = player.Character
	local head = c and c:FindFirstChild("Head") :: BasePart?
	if not head then
		return false
	end
	local to = head.Position
	if (to - from).Magnitude > range then
		return false
	end
	local list = table.clone(ignore)
	table.insert(list, c :: Model)
	table.insert(list, folder)
	sightParams.FilterDescendantsInstances = list
	local hit = workspace:Raycast(from, to - from, sightParams)
	if hit and hit.Instance:IsA("BasePart") and (hit.Instance.Transparency > 0.6 or not hit.Instance.CanCollide) then
		-- glass and see-through things don't block (one more cast past it)
		local list2 = table.clone(list)
		table.insert(list2, hit.Instance)
		sightParams.FilterDescendantsInstances = list2
		hit = workspace:Raycast(hit.Position, to - hit.Position, sightParams)
	end
	return hit == nil
end

local heliSees: (Player) -> boolean -- the helicopter section below
local function seenBy(player: Player): boolean
	if heliSees(player) then
		return true
	end
	for _, u in units do
		if u.target == player and u.phase ~= "leave" then
			if canSee(u.body.Position + Vector3.new(0, 3, 0), player, H.SeeRangeCar, { u.car }) then
				return true
			end
			for _, o in u.officers do
				local head = o.model:FindFirstChild("Head") :: BasePart?
				if head and o.hum.Health > 0 and canSee(head.Position, player, H.SeeRange, { o.model }) then
					return true
				end
			end
		end
	end
	return false
end

---------------------------------------------------------------- the helicopter (4+ stars)

local function buildHeli(): Model
	local m = Instance.new("Model")
	m.Name = "MTL_PoliceHeli"
	local function part(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, shape: Enum.PartType?): BasePart
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = mat or Enum.Material.SmoothPlastic
		if shape then
			p.Shape = shape
		end
		p.Parent = m
		return p
	end
	local navy, white, dark = Color3.fromRGB(22, 34, 70), Color3.fromRGB(235, 235, 238), Color3.fromRGB(24, 24, 28)
	local body = part("Body", Vector3.new(4.4, 4.0, 8.5), CFrame.new(), navy, Enum.Material.Metal)
	part("Stripe", Vector3.new(4.45, 0.7, 8.0), CFrame.new(0, -0.4, 0.1), white, Enum.Material.Metal)
	part("Canopy", Vector3.new(4.0, 3.0, 3.2), CFrame.new(0, 0.2, -4.6), Color3.fromRGB(30, 40, 54), Enum.Material.Glass).Transparency = 0.25
	part("Boom", Vector3.new(1.0, 1.0, 9.5), CFrame.new(0, 0.9, 8.8), navy, Enum.Material.Metal)
	part("Fin", Vector3.new(0.3, 3.0, 1.8), CFrame.new(0, 2.2, 13.2), navy, Enum.Material.Metal)
	part("TailRotor", Vector3.new(0.2, 3.2, 0.3), CFrame.new(0.45, 2.4, 13.4), dark, Enum.Material.Metal)
	for _, x in { -1.8, 1.8 } do
		part("Skid", Vector3.new(0.3, 0.3, 8.0), CFrame.new(x, -3.0, -0.4), dark, Enum.Material.Metal)
		part("Strut", Vector3.new(0.25, 1.2, 0.25), CFrame.new(x, -2.3, -2.0), dark, Enum.Material.Metal)
		part("Strut", Vector3.new(0.25, 1.2, 0.25), CFrame.new(x, -2.3, 1.6), dark, Enum.Material.Metal)
	end
	part("Mast", Vector3.new(0.6, 1.0, 0.6), CFrame.new(0, 2.5, 0), dark, Enum.Material.Metal)
	part("BladeA", Vector3.new(0.9, 0.12, 24), CFrame.new(0, 3.05, 0), dark, Enum.Material.Metal)
	part("BladeB", Vector3.new(24, 0.12, 0.9), CFrame.new(0, 3.05, 0), dark, Enum.Material.Metal)
	local beacon = part("Beacon", Vector3.new(0.4, 0.3, 0.4), CFrame.new(0, 2.1, 3.5), Color3.fromRGB(255, 40, 40), Enum.Material.Neon)
	local _ = beacon
	local lamp = part("Searchlight", Vector3.new(0.9, 0.9, 0.9), CFrame.new(0, -2.3, -3.2), Color3.fromRGB(255, 250, 220), Enum.Material.Neon, Enum.PartType.Ball)
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Angle = 40
	spot.Range = 120
	spot.Brightness = 6
	spot.Shadows = true
	spot.Color = Color3.fromRGB(255, 248, 225)
	spot.Parent = lamp
	m.PrimaryPart = body
	return m
end

local function spawnHeli(target: Player): Heli?
	local r = root(target)
	if not r then
		return nil
	end
	local Hc = P.Heli
	local m = buildHeli()
	local body, ap, ao = setupCarPhysics(m)
	ap.Responsiveness = Hc.Responsiveness
	ao.Responsiveness = Hc.Responsiveness
	-- the blades spin on the client side of physics: a welded rotor can't turn, so the blades are a separate
	-- assembly on a motor hinge
	for _, n in { "BladeA", "BladeB" } do
		local b = m:FindFirstChild(n) :: BasePart?
		local w = b and b:FindFirstChildOfClass("WeldConstraint")
		if w then
			w:Destroy()
		end
	end
	local bladeA = m:FindFirstChild("BladeA") :: BasePart
	local bladeB = m:FindFirstChild("BladeB") :: BasePart
	local bw = Instance.new("WeldConstraint")
	bw.Part0 = bladeA
	bw.Part1 = bladeB
	bw.Parent = bladeB
	local a0 = Instance.new("Attachment")
	a0.CFrame = CFrame.new(0, 3.05, 0) * CFrame.Angles(0, 0, math.rad(90))
	a0.Parent = body
	local a1 = Instance.new("Attachment")
	a1.CFrame = CFrame.Angles(0, 0, math.rad(90))
	a1.Parent = bladeA
	local hinge = Instance.new("HingeConstraint")
	hinge.Attachment0 = a0
	hinge.Attachment1 = a1
	hinge.ActuatorType = Enum.ActuatorType.Motor
	hinge.AngularVelocity = 28
	hinge.MotorMaxTorque = 1e7
	hinge.Parent = body
	-- a visible light cone down to a marker that follows the target
	local aim = Instance.new("Part")
	aim.Name = "MTL_HeliAim"
	aim.Size = Vector3.new(1, 1, 1)
	aim.Transparency = 1
	aim.Anchored = true
	aim.CanCollide, aim.CanQuery, aim.CanTouch = false, false, false
	aim.CFrame = CFrame.new(r.Position)
	aim.Parent = folder
	local lamp = m:FindFirstChild("Searchlight") :: BasePart
	local la = Instance.new("Attachment")
	la.Parent = lamp
	local ta = Instance.new("Attachment")
	ta.Parent = aim
	local beam = Instance.new("Beam")
	beam.Attachment0 = la
	beam.Attachment1 = ta
	beam.Width0 = 1.2
	beam.Width1 = 16
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 248, 225))
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0.9) })
	beam.Segments = 4
	beam.Parent = lamp
	local start = r.Position + Vector3.new(260, Hc.Height + 40, 0)
	m:PivotTo(CFrame.new(start))
	m.Parent = folder
	CollectionService:AddTag(m, "MTL_PoliceHeli")
	m:SetAttribute("MTL_Police", true)
	pcall(function()
		body:SetNetworkOwner(nil)
	end)
	local h: Heli = { target = target, model = m, body = body, align = ap, orient = ao, angle = rng:NextNumber(0, math.pi * 2), aim = aim }
	ap.Position = start
	helis[target] = h
	log("helicopter up over", target.Name)
	return h
end

local function removeHeli(player: Player)
	local h = helis[player]
	if not h then
		return
	end
	helis[player] = nil
	if h.model.Parent then
		h.model:Destroy()
	end
	if h.aim.Parent then
		h.aim:Destroy()
	end
end

local function heliStep(h: Heli, dt: number)
	local Hc = P.Heli
	if h.leaving then
		h.align.Position += Vector3.new(0, 30 * dt, 0) + h.body.CFrame.LookVector * 60 * dt
		if os.clock() > h.leaving then
			removeHeli(h.target)
		end
		return
	end
	local r = root(h.target)
	if not r then
		return
	end
	h.angle += dt * Hc.OrbitSpeed
	local want = r.Position + Vector3.new(math.cos(h.angle) * Hc.Orbit, Hc.Height, math.sin(h.angle) * Hc.Orbit)
	h.align.Position = want
	local fwd = Vector3.new(-math.sin(h.angle), 0, math.cos(h.angle)) -- along the circle
	h.orient.CFrame = CFrame.lookAt(Vector3.zero, fwd) * CFrame.Angles(math.rad(-6), 0, math.rad(-8))
	h.aim.CFrame = CFrame.new(r.Position - Vector3.new(0, 2.5, 0))
end

function heliSees(player: Player): boolean
	local h = helis[player]
	if not h or h.leaving then
		return false
	end
	return canSee(h.body.Position - Vector3.new(0, 3, 0), player, P.Heli.SeeRange, { h.model })
end

---------------------------------------------------------------- losing the heat at a car wash or a paint booth

local function inWash(player: Player): boolean
	local hum = humanoid(player)
	local seat = hum and hum.SeatPart
	if not seat or not seat:IsA("VehicleSeat") then
		return false
	end
	local pos = seat.Position
	for _, z in CollectionService:GetTagged("MTL_HeatWash") do
		if z:IsA("BasePart") then
			local l = z.CFrame:PointToObjectSpace(pos)
			local s = z.Size / 2
			if math.abs(l.X) <= s.X and math.abs(l.Y) <= s.Y and math.abs(l.Z) <= s.Z then
				return true
			end
		end
	end
	return false
end

---------------------------------------------------------------- booking

local function bust(player: Player)
	local s = state(player)
	if s.booked then
		return
	end
	s.booked = true
	local lost = 0
	if PoliceService.onBust then
		local ok, n = pcall(PoliceService.onBust :: any, player)
		lost = if ok and type(n) == "number" then n else 0
	end
	PoliceService.Busted:Fire(player)
	log(player.Name, "busted, lost", lost)
	local guns = sibling("GunService")
	if guns and guns.holster then
		pcall(guns.holster, player, "busted")
	end
	for _, u in units do
		if u.target == player then
			setLeaving(u)
		end
	end
	s.stars = 0
	s.unseen = 0
	publish(player, s)
	local r = root(player)
	if r then
		r.Anchored = true
	end
	send(player, { type = "booked", seconds = P.BookingSeconds, lost = lost })
	task.delay(P.BookingSeconds, function()
		s.booked = false
		if not player.Parent then
			return
		end
		local r2 = root(player)
		if r2 then
			r2.Anchored = false
			r2.CFrame = CFrame.new(P.BookedSpawn + Vector3.new(rng:NextNumber(-6, 6), 3, rng:NextNumber(-6, 6)))
			r2.AssemblyLinearVelocity = Vector3.zero
		end
		Notify.toast(player, "You're out. Clean money and guns are all still yours.")
	end)
end

---------------------------------------------------------------- officer AI

local function shoot(o: Officer, target: Player, stars: number)
	local tr = root(target)
	local th = humanoid(target)
	local head = o.model:FindFirstChild("Head") :: BasePart?
	if not tr or not th or not head or th.Health <= 0 then
		return
	end
	local guns = sibling("GunService")
	if guns and guns.inSafeZone then
		local ok, safe = pcall(guns.inSafeZone, target)
		if ok and safe then
			return -- never fire into a safe zone
		end
	end
	local from = head.Position + head.CFrame.LookVector * 1.2 + Vector3.new(0, -0.3, 0)
	local dist = (tr.Position - from).Magnitude
	local speed = flat(tr.AssemblyLinearVelocity).Magnitude
	local chance = CrimeRules.hitChance(dist, speed, P)
	local hit = rng:NextNumber() < chance
	local aimAt = tr.Position + Vector3.new(0, 0.6, 0)
	local endPos = if hit then aimAt else aimAt + Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(-1, 2), rng:NextNumber(-3, 3))
	if hit then
		th:TakeDamage(CrimeRules.perStar(P.ShotDamage, stars - 1))
	end
	-- face the shot
	o.root.CFrame = CFrame.lookAt(o.root.Position, Vector3.new(tr.Position.X, o.root.Position.Y, tr.Position.Z))
	for _, p in Players:GetPlayers() do
		local pr = root(p)
		if pr and (pr.Position - from).Magnitude < 600 then
			send(p, { type = "policeShot", from = from, to = endPos, hit = hit, target = if p == target then true else nil })
		end
	end
end

local function officerStep(o: Officer, u: Unit, dt: number)
	local target = u.target
	if not target or o.hum.Health <= 0 then
		return
	end
	local tr = root(target)
	local th = humanoid(target)
	if not tr or not th or th.Health <= 0 then
		o.hum:MoveTo(o.root.Position)
		return
	end
	local s = state(target)
	local d = (tr.Position - o.root.Position).Magnitude
	local stars = math.max(1, s.stars)
	o.hum.WalkSpeed = CrimeRules.perStar(P.OfficerSpeed, stars)
	local moving = d > 3.2
	if moving then
		o.hum:MoveTo(tr.Position)
	else
		o.hum:MoveTo(o.root.Position)
	end
	-- run / idle animation
	local speed = flat(o.root.AssemblyLinearVelocity).Magnitude
	if speed > 2 then
		if o.runTrack and not o.runTrack.IsPlaying then
			o.runTrack:Play(0.2)
			if o.idleTrack then
				o.idleTrack:Stop(0.2)
			end
		end
		if o.runTrack then
			o.runTrack:AdjustSpeed(math.clamp(speed / 16, 0.6, 1.4))
		end
	elseif o.idleTrack and not o.idleTrack.IsPlaying then
		o.idleTrack:Play(0.2)
		if o.runTrack then
			o.runTrack:Stop(0.2)
		end
	end
	-- stuck on a fence / kerb: hop
	if moving and (o.root.Position - o.lastPos).Magnitude < 0.4 * dt * 10 then
		o.stuck += dt
		if o.stuck > 0.8 then
			o.hum.Jump = true
			o.stuck = 0
		end
	else
		o.stuck = 0
	end
	o.lastPos = o.root.Position
	-- aim pose for clients (CrimeController raises the gun arm)
	local shooting = s.stars >= P.ShootFrom and d <= P.ShootRange
	o.model:SetAttribute("MTL_OfficerAim", shooting)
	if shooting and os.clock() >= o.nextShot then
		local head = o.model:FindFirstChild("Head") :: BasePart?
		if head and canSee(head.Position, target, P.ShootRange, { o.model }) then
			shoot(o, target, s.stars)
		end
		o.nextShot = os.clock() + CrimeRules.perStar(P.ShotEvery, s.stars - 1) * rng:NextNumber(0.85, 1.2)
	end
	-- cuffs
	local tspeed = flat(tr.AssemblyLinearVelocity).Magnitude
	if d <= P.CuffRange and tspeed < P.CuffMaxSpeed and not th.SeatPart then
		o.cuff += dt
		if o.cuff >= P.CuffSeconds then
			o.cuff = 0
			bust(target)
		end
	else
		o.cuff = math.max(0, o.cuff - dt * 2)
	end
end

local function unitStep(u: Unit, dt: number)
	local now = os.clock()
	local target = u.target
	if u.phase == "leave" then
		if now > u.leaveUntil then
			removeUnit(u)
			return
		end
	elseif not target or not target.Parent or state(target).stars <= 0 then
		u.calmFor += dt
		if u.calmFor >= P.DespawnAfterCalm or not target or not target.Parent then
			setLeaving(u)
		end
		-- officers stand down
		for _, o in u.officers do
			o.hum:MoveTo(o.root.Position)
			o.model:SetAttribute("MTL_OfficerAim", false)
		end
		return
	else
		u.calmFor = 0
	end

	local tr = if target then root(target) else nil
	if u.phase ~= "leave" and tr then
		local dFlat = (flat(tr.Position) - flat(u.pos)).Magnitude
		if dFlat > P.GiveUpDistance then
			removeUnit(u)
			return
		end
		if u.phase == "drive" then
			if now - u.routeAt > P.ReRoute then
				u.routeAt = now
				u.path = routeTo(u.pos, tr.Position)
				u.seg = 1
			end
			local th = target and humanoid(target :: Player)
			local inCar = th and th.SeatPart ~= nil
			if dFlat <= P.StopDistance + (if inCar then 0 else 10) and not inCar then
				-- pull up: officers out on both sides
				u.phase = "foot"
				local stars = state(target :: Player).stars
				-- don't pull up on top of a car that's already here: park a car length further back per unit
				local slot = 0
				for _, other in units do
					if other ~= u and other.target == target and other.phase == "foot" and (other.pos - u.pos).Magnitude < 16 then
						slot += 1
					end
				end
				if slot > 0 then
					u.pos -= u.look * (slot * 16)
					placeCar(u)
				end
				for i = 1, P.OfficersPerCar do
					local side = if i % 2 == 1 then -1 else 1
					local cf = CFrame.lookAt(u.pos, u.pos + u.look) * CFrame.new(side * 5, 0, -1)
					local o = spawnOfficer(cf, stars)
					if o then
						table.insert(u.officers, o)
					end
				end
				return
			end
		elseif u.phase == "foot" then
			-- target ran off (or got in a car): officers get back in, the car chases again
			local far = true
			for _, o in u.officers do
				if o.hum.Health > 0 and (o.root.Position - tr.Position).Magnitude < 140 then
					far = false
				end
			end
			local th = humanoid(target :: Player)
			if far or (th and th.SeatPart and dFlat > 60) then
				dropOfficers(u)
				u.phase = "drive"
				u.routeAt = 0
			else
				for _, o in u.officers do
					officerStep(o, u, dt)
				end
				return
			end
		end
	end

	-- drive along the path
	local remaining = u.speed * dt
	while remaining > 0 and u.seg < #u.path do
		local a, b = u.pos, u.path[u.seg + 1]
		local leg = flat(b - a)
		local len = leg.Magnitude
		if len < 0.5 then
			u.seg += 1
			continue
		end
		local step = math.min(remaining, len)
		u.pos = a + (b - a).Unit * step
		-- turn smoothly toward the leg
		local want = leg.Unit
		u.look = u.look:Lerp(want, math.clamp(dt * 6, 0, 1))
		if u.look.Magnitude < 0.01 then
			u.look = want
		end
		u.look = flat(u.look).Unit
		remaining -= step
		if step >= len - 0.01 then
			u.seg += 1
		end
	end
	placeCar(u)
end

---------------------------------------------------------------- the loop

local function tick(dt: number)
	for p, h in helis do
		if not p.Parent then
			removeHeli(p)
		elseif not h.leaving and PoliceService.heat(p) < P.Heli.FromStars then
			h.leaving = os.clock() + 8
		end
	end
	-- heat bookkeeping per player
	for player, s in heat do
		if not player.Parent then
			heat[player] = nil
			continue
		end
		if s.stars <= 0 or s.booked then
			continue
		end
		local old = s.stars
		if seenBy(player) then
			s.unseen = 0
			s.seenAt = os.clock()
		else
			s.unseen += dt
		end
		-- a car wash tunnel / paint booth while nobody's watching
		if s.unseen >= (H.WashUnseenSeconds or 1.5) and inWash(player) then
			s.stars = 0
			s.unseen = 0
			Notify.toast(player, "Fresh rinse. Nobody's sure it was you. The heat's off.", Color3.fromRGB(92, 196, 104))
		end
		-- hiding in your own flat
		if player:GetAttribute("MTL_InHome") then
			s.homeFor += dt
			if s.homeFor >= H.HideHomeSeconds then
				s.stars = 0
				Notify.toast(player, "You laid low. The heat's off.")
			end
		else
			s.homeFor = 0
		end
		s.stars, s.unseen = CrimeRules.decay(s.stars, s.unseen, H)
		if s.stars ~= old then
			PoliceService.HeatChanged:Fire(player, s.stars, old)
			if s.stars == 0 then
				Notify.toast(player, "You lost them.", Color3.fromRGB(92, 196, 104))
			end
		end
		publish(player, s)
		-- dispatch
		if P.Enabled and s.stars > 0 then
			local want = CrimeRules.unitsFor(s.stars, P)
			if unitsOn(player) < want then
				spawnUnit(player, s.stars)
			end
		end
		-- the helicopter comes in at Heli.FromStars and peels off below it
		local hc = P.Heli
		if hc and P.Enabled then
			local h = helis[player]
			if s.stars >= hc.FromStars and not h then
				spawnHeli(player)
			elseif s.stars < hc.FromStars and h and not h.leaving then
				h.leaving = os.clock() + 8
			end
		end
	end
end

function PoliceService.init()
	folder = Instance.new("Folder")
	folder.Name = "MTL_Police"
	folder.Parent = workspace
	pcall(function()
		local PhysicsService = game:GetService("PhysicsService")
		if not PhysicsService:IsCollisionGroupRegistered("MTL_Officers") then
			PhysicsService:RegisterCollisionGroup("MTL_Officers")
		end
		PhysicsService:CollisionGroupSetCollidable("MTL_Officers", "MTL_Officers", false)
	end)

	task.spawn(ensureGraph)

	-- heat + dispatch at 4 Hz (one new unit per tick at most per player: they arrive staggered)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.25)
			local now = os.clock()
			local ok, err = pcall(tick, now - last)
			if not ok then
				warn("[MTL Police] tick failed:", err)
			end
			last = now
		end
	end)
	-- unit movement every frame (cars glide; officers think)
	RunService.Heartbeat:Connect(function(dt)
		for _, h in helis do
			local ok, err = pcall(heliStep, h, dt)
			if not ok then
				warn("[MTL Police] heli failed:", err)
				removeHeli(h.target)
			end
		end
		for i = #units, 1, -1 do
			local u = units[i]
			if u then
				local ok, err = pcall(unitStep, u, dt)
				if not ok then
					warn("[MTL Police] unit failed:", err)
					removeUnit(u)
				end
			end
		end
	end)

	-- shooting at the police, or dropping one
	task.defer(function()
		local guns = sibling("GunService")
		if not guns then
			return
		end
		if guns.Damaged then
			guns.Damaged:Connect(function(attacker: Player, victim: Instance)
				if victim and victim:GetAttribute("MTL_Police") then
					PoliceService.raise(attacker, 2, "shot an officer")
				end
			end)
		end
		if guns.Killed then
			guns.Killed:Connect(function(attacker: Player, victim: Instance)
				if victim and victim:GetAttribute("MTL_Police") then
					-- at least KillHeat, and every officer after that is one more star
					PoliceService.raise(attacker, math.max(P.KillHeat, PoliceService.heat(attacker) + (P.KillBump or 1)), "dropped an officer")
					task.delay(6, function()
						if victim.Parent then
							victim:Destroy()
						end
					end)
				end
			end)
		end
		if guns.Fired then
			-- shots near a police unit: 1 star ("shots fired"), only for live guns that can hurt someone
			guns.Fired:Connect(function(player: Player)
				local r = root(player)
				if not r then
					return
				end
				for _, u in units do
					if u.phase ~= "leave" and (u.body.Position - r.Position).Magnitude < 70 then
						PoliceService.raise(player, 1, "shots fired near police")
						return
					end
				end
			end)
		end
	end)

	local function watch(player: Player)
		player.CharacterAdded:Connect(function(char)
			local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
			if hum then
				hum.Died:Connect(function()
					if H.ClearOnDeath then
						PoliceService.clear(player, "went down")
					end
				end)
			end
		end)
		player:SetAttribute(H.AttrName, 0)
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		heat[player] = nil
		removeHeli(player)
		for _, u in units do
			if u.target == player then
				setLeaving(u)
			end
		end
	end)
	log("ready")
end

-- Studio: _G.MTL.Police.debug(player, stars) puts heat on you without a crime.
function PoliceService.debug(player: Player, stars: number?)
	assert(RunService:IsStudio(), "[MTL Police] debug is Studio-only")
	PoliceService.raise(player, stars or 1, "debug")
end

function PoliceService.units(): number
	return #units
end

return PoliceService
