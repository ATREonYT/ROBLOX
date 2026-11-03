--!strict
-- Local (this client only) actors and props for cutscenes and mission scenes. Nothing here replicates, so every
-- player's scene is private and costs the server nothing. Required by CutsceneController and MissionController.
--   Actors.spawn(rigName, parent) -> Actor?      rigName = a ReplicatedStorage.MTL_Actors.<Name> rig, or "@player"
--   Actors.adopt(model, name, parent) -> Actor?  a model you already cloned (ambient people)
--   Actors.place(actor, groundCFrame)            feet on the floor at that CFrame (facing its LookVector)
--   Actors.render(actor, state, now)             Rig.State -> pose (call every frame)
--   Actors.setHidden(actor, bool)   Actors.destroy(actor)
--   Actors.prop(name, opts) -> Model             "CrewCar" (opts.hazards), "Mask", "CashBag", or registerProp()
--   Actors.registerProp(name, fn(opts) -> Model) Piece 4: PC, bed, etc. (or drop a model in MTL_Actors.<name>)
--   Actors.floor(position, ignore?) -> y         ground height under a point (falls back to the point's y)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Rig = require(ReplicatedStorage.MTL.Rig)
local Missions = require(ReplicatedStorage.MTL.Config.Missions)
local Theme = require(ReplicatedStorage.MTL.UI.Theme)

local player = Players.LocalPlayer

local Actors = {}

export type Actor = {
	name: string,
	model: Model,
	root: BasePart,
	joints: Rig.Joints,
	height: number,
	parts: { BasePart },
	decals: { Decal },
	hidden: boolean,
	tracks: { [string]: AnimationTrack },
	lastGesture: string?,
}

local function folder(): Folder
	local f = workspace:FindFirstChild("MTL_LocalScene")
	if not f then
		f = Instance.new("Folder")
		f.Name = "MTL_LocalScene"
		f.Parent = workspace
	end
	return f :: Folder
end
Actors.folder = folder

local ignoreParams = RaycastParams.new()
ignoreParams.FilterType = Enum.RaycastFilterType.Exclude

function Actors.floor(pos: Vector3, ignore: { Instance }?): number
	local list: { Instance } = { folder() }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	for _, i in ignore or {} do
		table.insert(list, i)
	end
	-- only real, solid ground counts: invisible lot "Footprint" volumes, trigger zones and glass-free markers made
	-- actors float (Alex: "the character floats"), so skip anything you can walk through or can't see
	ignoreParams.RespectCanCollide = true
	local origin = pos + Vector3.new(0, 4, 0)
	for _ = 1, 6 do
		ignoreParams.FilterDescendantsInstances = list
		local hit = workspace:Raycast(origin, Vector3.new(0, -40, 0), ignoreParams)
		if not hit then
			return pos.Y
		end
		local part = hit.Instance :: BasePart
		if part:IsA("BasePart") and part.Transparency < 0.95 then
			return hit.Position.Y
		end
		table.insert(list, part)
	end
	return pos.Y
end

local function strip(model: Instance)
	for _, d in model:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("Tool") or d:IsA("ForceField") or d:IsA("Sound") then
			d:Destroy()
		end
	end
end

-- A simple blocky R6 rig, used only if neither a template nor the server-built rig exists (the scene still plays).
local function fallbackRig(name: string): Model
	local cfg = (Missions.Actors :: any)[name] or {}
	local skin = cfg.Skin or Color3.fromRGB(200, 160, 130)
	local shirt = cfg.Shirt or Color3.fromRGB(80, 80, 90)
	local pants = cfg.Pants or Color3.fromRGB(40, 40, 46)
	local m = Instance.new("Model")
	m.Name = name
	local function p(n: string, size: Vector3, color: Color3): Part
		local part = Instance.new("Part")
		part.Name = n
		part.Size = size
		part.Color = color
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CanCollide = false
		part.Parent = m
		return part
	end
	local root = p("HumanoidRootPart", Vector3.new(2, 2, 1), skin)
	root.Transparency = 1
	local torso = p("Torso", Vector3.new(2, 2, 1), shirt)
	local head = p("Head", Vector3.new(1.2, 1.2, 1.2), skin)
	local ra = p("Right Arm", Vector3.new(1, 2, 1), skin)
	local la = p("Left Arm", Vector3.new(1, 2, 1), skin)
	local rl = p("Right Leg", Vector3.new(1, 2, 1), pants)
	local ll = p("Left Leg", Vector3.new(1, 2, 1), pants)
	local function motor(n: string, p0: BasePart, p1: BasePart, c0: CFrame, c1: CFrame)
		local mt = Instance.new("Motor6D")
		mt.Name = n
		mt.Part0 = p0
		mt.Part1 = p1
		mt.C0 = c0
		mt.C1 = c1
		mt.Parent = p0
	end
	local R90 = CFrame.Angles(0, math.rad(90), 0)
	local L90 = CFrame.Angles(0, math.rad(-90), 0)
	motor("RootJoint", root, torso, CFrame.new(), CFrame.new())
	motor("Neck", torso, head, CFrame.new(0, 1, 0), CFrame.new(0, -0.6, 0))
	motor("Right Shoulder", torso, ra, CFrame.new(1, 0.5, 0) * R90, CFrame.new(-0.5, 0.5, 0) * R90)
	motor("Left Shoulder", torso, la, CFrame.new(-1, 0.5, 0) * L90, CFrame.new(0.5, 0.5, 0) * L90)
	motor("Right Hip", torso, rl, CFrame.new(1, -1, 0) * R90, CFrame.new(0.5, 1, 0) * R90)
	motor("Left Hip", torso, ll, CFrame.new(-1, -1, 0) * L90, CFrame.new(-0.5, 1, 0) * L90)
	local h = Instance.new("Humanoid")
	h.RigType = Enum.HumanoidRigType.R6
	h.Parent = m
	m.PrimaryPart = root
	return m
end

-- wait = true for crew rigs (the server builds them a moment after it starts); props never wait.
local function template(name: string, wait: boolean?): Model?
	local lib = ReplicatedStorage:FindFirstChild("MTL_Actors")
	if not lib and wait then
		lib = ReplicatedStorage:WaitForChild("MTL_Actors", 3)
	end
	local t = lib and (lib:FindFirstChild(name) or (if wait then lib:WaitForChild(name, 3) else nil))
	return if t and t:IsA("Model") then t else nil
end

function Actors.spawn(rigName: string, parent: Instance?): Actor?
	local model: Model? = nil
	if rigName == "@player" then
		local char = player.Character
		if char then
			local was = char.Archivable
			char.Archivable = true
			local ok, clone = pcall(function()
				return char:Clone()
			end)
			char.Archivable = was
			if ok and clone then
				model = clone
			end
		end
	else
		local t = template(rigName, true)
		if t then
			local was = t.Archivable
			t.Archivable = true
			model = t:Clone()
			t.Archivable = was
		end
	end
	if not model then
		model = fallbackRig(if rigName == "@player" then player.Name else rigName)
	end
	assert(model)
	return Actors.adopt(model, rigName, parent)
end

-- Turns any humanoid model (already cloned) into a puppet actor. AmbientPeople uses it for MTL_AmbientRigs clones.
function Actors.adopt(model: Model, rigName: string, parent: Instance?): Actor?
	strip(model)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not root or not hum then
		model:Destroy()
		warn("[MTL Cutscene] rig has no Humanoid/HumanoidRootPart:", rigName)
		return nil
	end
	model.Name = "Actor_" .. (if rigName == "@player" then "Player" else rigName)
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.BreakJointsOnDeath = false
	hum.EvaluateStateMachine = false -- a puppet: no physics states fighting our CFrames
	local parts, decals = {}, {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			table.insert(parts, d)
		elseif d:IsA("Decal") then
			table.insert(decals, d)
		end
	end
	root.Anchored = true
	model.PrimaryPart = root
	model.Parent = parent or folder()
	local actor: Actor = {
		name = rigName,
		model = model,
		root = root,
		joints = Rig.joints(model),
		height = Rig.rootHeight(model),
		parts = parts,
		decals = decals,
		hidden = false,
		tracks = {},
		lastGesture = nil,
	}
	return actor
end

-- Puts the actor's feet on the floor at `cf` (cf.Position is a floor point; the actor faces cf.LookVector).
function Actors.place(actor: Actor, cf: CFrame, drop: number?)
	actor.root.CFrame = cf + Vector3.new(0, actor.height - (drop or 0), 0)
end

function Actors.setHidden(actor: Actor, hidden: boolean)
	if actor.hidden == hidden then
		return
	end
	actor.hidden = hidden
	for _, p in actor.parts do
		p.LocalTransparencyModifier = if hidden then 1 else 0
	end
	for _, d in actor.decals do
		d.LocalTransparencyModifier = if hidden then 1 else 0
	end
end

-- Real animations (Config/Missions.Animations). Layers:
--   base    Idle (no held pose) or Walk (while walking), looped, under everything
--   gesture one-shot (Wave, Point, Nod...) on top, Action priority
-- While any animation plays, the Animator owns Motor6D.Transform; our head turn (look at the speaker) then goes
-- into the Neck's C0 instead, so both show. Held poses (Lean, Phone, Sit...) and gestures without an id stay
-- procedural (Rig.lua writes Transform). R6 rigs are always procedural.
local function animId(name: string): number?
	local id = (Missions.Animations :: any)[name]
	return if type(id) == "number" and id ~= 0 then id else nil
end

local function loadTrack(actor: Actor, name: string): AnimationTrack?
	local track = actor.tracks[name]
	if track then
		return track
	end
	local id = animId(name)
	local hum = actor.model:FindFirstChildOfClass("Humanoid")
	if not id or not hum or hum.RigType ~= Enum.HumanoidRigType.R15 then
		return nil
	end
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local anim = Instance.new("Animation")
	anim.AnimationId = "rbxassetid://" .. id
	local ok, t = pcall(function()
		return (animator :: Animator):LoadAnimation(anim)
	end)
	if not ok or not t then
		return nil
	end
	if name == "Idle" then
		t.Priority = Enum.AnimationPriority.Idle
		t.Looped = true
	elseif name == "Walk" then
		t.Priority = Enum.AnimationPriority.Movement
		t.Looped = true
	else
		t.Priority = Enum.AnimationPriority.Action
		t.Looped = false
	end
	actor.tracks[name] = t
	return t
end

local function setBase(actor: Actor, name: string?)
	local a = actor :: any
	if a.base == name then
		return
	end
	if a.base and actor.tracks[a.base] then
		actor.tracks[a.base]:Stop(0.25)
	end
	a.base = nil
	if name then
		local t = loadTrack(actor, name)
		if t then
			t:Play(0.25)
			if name == "Walk" then
				t:AdjustSpeed(Missions.WalkAnimSpeed or 0.8)
			end
			a.base = name
		end
	end
end

local function neckC0(actor: Actor, yaw: number?)
	local j = actor.joints.Neck
	if not j then
		return
	end
	if yaw and yaw ~= 0 then
		local r = CFrame.fromEulerAnglesYXZ(0, math.clamp(yaw, -0.8, 0.8), 0)
		j.motor.C0 = j.c0 * (j.rot0:Inverse() * r * j.rot0)
	else
		j.motor.C0 = j.c0
	end
end

-- A phone in the right hand while the pose is a phone pose ("Phone", "SitPhone"): dark body, glowing screen,
-- a little screen light on the face. Same look as PropertyController's PhoneOut beat (it reuses this one).
local PHONE_POSES = { Phone = true, SitPhone = true }
local function setPhone(actor: Actor, on: boolean)
	local existing = actor.model:FindFirstChild("ScenePhone")
	if not on then
		if existing and existing:GetAttribute("MTL_PosePhone") then
			existing:Destroy()
			local glow = actor.model:FindFirstChild("ScenePhoneGlow")
			if glow then
				glow:Destroy()
			end
		end
		return
	end
	if existing then
		return
	end
	local hand = actor.model:FindFirstChild("RightHand") or actor.model:FindFirstChild("Right Arm")
	if not hand or not hand:IsA("BasePart") then
		return
	end
	local phone = Instance.new("Part")
	phone.Name = "ScenePhone"
	phone:SetAttribute("MTL_PosePhone", true)
	phone.Size = Vector3.new(0.45, 0.85, 0.08)
	phone.Color = Color3.fromRGB(18, 19, 24)
	phone.CanCollide, phone.CanQuery, phone.CanTouch, phone.Massless, phone.CastShadow = false, false, false, true, false
	local screen = Instance.new("Part")
	screen.Name = "ScenePhoneGlow"
	screen.Size = Vector3.new(0.38, 0.75, 0.02)
	screen.Material = Enum.Material.Neon
	screen.Color = Color3.fromRGB(150, 190, 255)
	screen.CanCollide, screen.CanQuery, screen.CanTouch, screen.Massless, screen.CastShadow = false, false, false, true, false
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(150, 190, 255)
	light.Brightness = 0.9
	light.Range = 4
	light.Parent = screen
	local yOff = if hand.Name == "RightHand" then -0.25 else -1.1
	phone.CFrame = hand.CFrame * CFrame.new(0, yOff, -0.2) * CFrame.Angles(math.rad(-70), 0, 0)
	screen.CFrame = phone.CFrame * CFrame.new(0, 0, -0.05)
	local w1 = Instance.new("WeldConstraint")
	w1.Part0 = hand
	w1.Part1 = phone
	w1.Parent = phone
	local w2 = Instance.new("WeldConstraint")
	w2.Part0 = phone
	w2.Part1 = screen
	w2.Parent = screen
	phone.Parent = actor.model
	screen.Parent = actor.model
end

-- Small items in the right hand ({ t, actor, hold = "Soda" }): built from parts, welded to the hand, swapped when
-- the held name changes. Phone poses keep their own phone (setPhone).
Actors.HeldItems = {
	Soda = { size = Vector3.new(0.42, 0.75, 0.42), color = Color3.fromRGB(255, 150, 40), shape = "Cylinder", label = Color3.fromRGB(70, 160, 60) },
	Bill = { size = Vector3.new(0.75, 0.02, 0.34), color = Color3.fromRGB(150, 190, 140) },
	Card = { size = Vector3.new(0.6, 0.02, 0.36), color = Color3.fromRGB(240, 236, 226) },
	Keys = { size = Vector3.new(0.18, 0.5, 0.06), color = Color3.fromRGB(200, 196, 180), ring = true },
	Envelope = { size = Vector3.new(0.95, 0.06, 0.5), color = Color3.fromRGB(226, 208, 170) },
	Clipboard = { size = Vector3.new(0.85, 1.15, 0.06), color = Color3.fromRGB(150, 110, 70), paper = true },
}
local function setHeld(actor: Actor, item: string?)
	local a = actor :: any
	if a.heldName == item then
		return
	end
	a.heldName = item
	local old = actor.model:FindFirstChild("SceneHeld")
	if old then
		old:Destroy()
	end
	local spec = item and Actors.HeldItems[item]
	local hand = actor.model:FindFirstChild("RightHand") or actor.model:FindFirstChild("Right Arm")
	if not spec or not hand or not hand:IsA("BasePart") then
		return
	end
	local p = Instance.new("Part")
	p.Name = "SceneHeld"
	p.Size = spec.size
	p.Color = spec.color
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide, p.CanQuery, p.CanTouch, p.Massless, p.CastShadow = false, false, false, true, false
	local yOff = if hand.Name == "RightHand" then -0.3 else -1.1
	if spec.shape == "Cylinder" then
		-- a can stands upright in the fist (a cylinder's axis is X: turn it up)
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(spec.size.Y, spec.size.X, spec.size.Z)
		p.CFrame = hand.CFrame * CFrame.new(0, yOff, -0.15) * CFrame.Angles(0, 0, math.rad(90))
		local band = Instance.new("Part")
		band.Name = "Label"
		band.Shape = Enum.PartType.Cylinder
		band.Size = Vector3.new(spec.size.Y * 0.45, spec.size.X + 0.02, spec.size.Z + 0.02)
		band.Color = spec.label
		band.Material = Enum.Material.SmoothPlastic
		band.CanCollide, band.CanQuery, band.CanTouch, band.Massless, band.CastShadow = false, false, false, true, false
		band.CFrame = p.CFrame
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = p, band
		w.Parent = band
		band.Parent = p
	else
		-- flat things lie across the fingers, pinched at one end
		p.CFrame = hand.CFrame * CFrame.new(0.1, yOff - 0.05, -0.25) * CFrame.Angles(math.rad(-20), 0, 0)
		if spec.paper then
			local sheet = Instance.new("Part")
			sheet.Name = "Paper"
			sheet.Size = Vector3.new(spec.size.X - 0.12, spec.size.Y - 0.2, 0.02)
			sheet.Color = Color3.fromRGB(240, 238, 230)
			sheet.CanCollide, sheet.CanQuery, sheet.CanTouch, sheet.Massless, sheet.CastShadow = false, false, false, true, false
			sheet.CFrame = p.CFrame * CFrame.new(0, -0.05, -0.04)
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = p, sheet
			w.Parent = sheet
			sheet.Parent = p
		end
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = p
	weld.Parent = p
	p.Parent = actor.model
end

function Actors.render(actor: Actor, state: Rig.State, now: number)
	local s = state
	local a = actor :: any
	setPhone(actor, s.pose ~= nil and PHONE_POSES[s.pose] == true)
	setHeld(actor, (s :: any).hold)
	-- gesture: start its animation once when it begins. Not while a held pose (sitting, leaning, on the phone) is
	-- on: a full-body emote would stand a seated actor up, so those gestures stay procedural.
	local heldNow = s.pose ~= nil and s.pose ~= "None"
	if s.gesture and s.gesture ~= actor.lastGesture then
		actor.lastGesture = s.gesture
		local t = if heldNow then nil else loadTrack(actor, s.gesture)
		if t then
			t:Play(0.15)
		end
	elseif not s.gesture then
		actor.lastGesture = nil
	end
	local gTrack = s.gesture and actor.tracks[s.gesture]
	local gestureAnimated = gTrack ~= nil and gTrack.IsPlaying
	local held = s.pose ~= nil and s.pose ~= "None"
	local proceduralGesture = s.gesture ~= nil and not gestureAnimated and Rig.Gestures[s.gesture] ~= nil
	-- base layer: idle when standing free, walk while walking; off for held poses and procedural gestures
	local base: string? = nil
	if (s.walk or 0) > 0.05 then
		base = "Walk"
	elseif not held and not proceduralGesture then
		base = "Idle"
	end
	setBase(actor, base)
	-- feet match the ground: the walk cycle plays at the speed the actor really moves (measured frame to frame,
	-- smoothed), so steps never slide or moonwalk as a walk eases in and out
	local pos = actor.root.Position
	if a.lastPos and a.lastNow and now > a.lastNow then
		local d = Vector3.new(pos.X - a.lastPos.X, 0, pos.Z - a.lastPos.Z).Magnitude
		local v = d / (now - a.lastNow)
		a.speed = (a.speed or v) + (v - (a.speed or v)) * 0.25
	end
	a.lastPos, a.lastNow = pos, now
	if a.base == "Walk" and actor.tracks.Walk then
		actor.tracks.Walk:AdjustSpeed(math.clamp((a.speed or 5) / (Missions.WalkAnimRef or 10), 0.25, 1.8))
	end
	local animated = gestureAnimated or (a.base ~= nil and actor.tracks[a.base] ~= nil and actor.tracks[a.base].IsPlaying)
	if animated and not held and not proceduralGesture then
		-- the Animator drives the body; we only turn the head (through C0)
		neckC0(actor, s.lookYaw)
		a.c0Used = true
	else
		if a.c0Used then
			neckC0(actor, nil)
			a.c0Used = false
		end
		local copy = s
		if gestureAnimated then
			copy = table.clone(s) :: any
			copy.gesture = nil
		end
		Rig.apply(actor.joints, Rig.compose(copy, now), "Transform")
	end
end

function Actors.destroy(actor: Actor?)
	if actor and actor.model then
		actor.model:Destroy()
	end
end

---------------------------------------------------------------- props

local propBuilders: { [string]: (any) -> Model } = {}

function Actors.registerProp(name: string, fn: (any) -> Model)
	propBuilders[name] = fn
end

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		if k ~= "Parent" then
			(p :: any)[k] = v
		end
	end
	p.Parent = props.Parent
	return p
end
Actors.part = part

-- Placeholder getaway car (front = -Z, origin at the floor). Alex: a model named CrewCar in MTL_Actors replaces it
-- (PrimaryPart at floor level, front facing -Z; parts named "Hazard" blink when hazards are on).
Actors.registerProp("CrewCar", function(opts: any): Model
	local m = Instance.new("Model")
	m.Name = "CrewCar"
	local body = Color3.fromRGB(32, 34, 40)
	local base = part({ Name = "Base", Size = Vector3.new(6.4, 0.2, 13), Transparency = 1, CFrame = CFrame.new(0, 0.1, 0), Parent = m })
	part({ Name = "Body", Size = Vector3.new(6.4, 2.2, 13), Color = body, Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(0, 2.1, 0), Parent = m })
	part({ Name = "Cabin", Size = Vector3.new(5.8, 1.9, 6.4), Color = body, Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(0, 4.15, 0.6), Parent = m })
	part({ Name = "Glass", Size = Vector3.new(5.9, 1.5, 6.5), Color = Color3.fromRGB(20, 26, 36), Material = Enum.Material.Glass, Transparency = 0.25, CFrame = CFrame.new(0, 4.2, 0.6), Parent = m })
	for i, z in { -4.4, 4.4 } do
		for j, x in { -3.1, 3.1 } do
			part({
				Name = "Wheel",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.9, 2.4, 2.4),
				Color = Color3.fromRGB(18, 18, 20),
				CFrame = CFrame.new(x, 1.2, z),
				Parent = m,
			})
			local front = i == 1
			local light = part({
				Name = "Hazard",
				Size = Vector3.new(0.9, 0.4, 0.2),
				Color = Theme.Mission.Hazard,
				Material = Enum.Material.Neon,
				CFrame = CFrame.new(x * 0.8, 2.6, if front then -6.55 else 6.55),
				Transparency = 0.6,
				Parent = m,
			})
			light:SetAttribute("Side", j)
			if front then
				part({ Name = "Headlight", Size = Vector3.new(1.2, 0.5, 0.2), Color = Color3.fromRGB(255, 250, 230), Material = Enum.Material.Neon, CFrame = CFrame.new(x * 0.62, 2.4, -6.55), Parent = m })
			else
				part({ Name = "Taillight", Size = Vector3.new(1.2, 0.5, 0.2), Color = Color3.fromRGB(200, 20, 30), Material = Enum.Material.Neon, CFrame = CFrame.new(x * 0.62, 2.4, 6.55), Parent = m })
			end
		end
	end
	local lamp = Instance.new("PointLight")
	lamp.Name = "HazardLight"
	lamp.Color = Theme.Mission.Hazard
	lamp.Range = 16
	lamp.Brightness = 0
	lamp.Parent = base
	m.PrimaryPart = base
	return m
end)

Actors.registerProp("Mask", function(): Model
	local m = Instance.new("Model")
	m.Name = "Mask"
	local b = part({ Name = "Box", Size = Vector3.new(1.6, 0.8, 1.2), Color = Color3.fromRGB(150, 110, 70), Material = Enum.Material.Cardboard, CFrame = CFrame.new(0, 0.4, 0), Parent = m })
	part({ Name = "Mask", Size = Vector3.new(1, 0.3, 0.9), Color = Color3.fromRGB(20, 20, 22), CFrame = CFrame.new(0, 0.95, 0), Parent = m })
	m.PrimaryPart = b
	return m
end)

-- One leaf of an automatic sliding shop door: framed glass with a pull bar. Origin at the floor, centred.
-- Cutscenes put two of them in a doorway and slide them apart (FirstDay: the Food Mart's front door).
Actors.registerProp("GlassDoor", function(): Model
	local m = Instance.new("Model")
	m.Name = "GlassDoor"
	local base = part({ Name = "Base", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CFrame = CFrame.new(0, 0, 0), Parent = m })
	local frame = Color3.fromRGB(196, 200, 206)
	part({ Name = "Glass", Size = Vector3.new(2.7, 7.9, 0.1), Color = Color3.fromRGB(170, 205, 215), Material = Enum.Material.Glass, Transparency = 0.55, CFrame = CFrame.new(0, 4.05, 0), Parent = m })
	part({ Name = "Top", Size = Vector3.new(2.85, 0.18, 0.18), Color = frame, Material = Enum.Material.Metal, CFrame = CFrame.new(0, 8.05, 0), Parent = m })
	part({ Name = "Bottom", Size = Vector3.new(2.85, 0.3, 0.18), Color = frame, Material = Enum.Material.Metal, CFrame = CFrame.new(0, 0.15, 0), Parent = m })
	part({ Name = "SideA", Size = Vector3.new(0.12, 8, 0.18), Color = frame, Material = Enum.Material.Metal, CFrame = CFrame.new(-1.38, 4.05, 0), Parent = m })
	part({ Name = "SideB", Size = Vector3.new(0.12, 8, 0.18), Color = frame, Material = Enum.Material.Metal, CFrame = CFrame.new(1.38, 4.05, 0), Parent = m })
	part({ Name = "Bar", Size = Vector3.new(0.1, 1.6, 0.1), Color = frame, Material = Enum.Material.Metal, CFrame = CFrame.new(1.1, 3.9, -0.14), Parent = m })
	m.PrimaryPart = base
	return m
end)

-- Patel's tab book (Story Bible Act 1 plant): an open ledger lying on the counter. Origin = the surface it rests on.
Actors.registerProp("TabBook", function(): Model
	local m = Instance.new("Model")
	m.Name = "TabBook"
	local base = part({ Name = "Base", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CFrame = CFrame.new(0, 0, 0), Parent = m })
	local cover = Color3.fromRGB(92, 30, 28)
	local paper = Color3.fromRGB(236, 228, 206)
	part({ Name = "Cover", Size = Vector3.new(1.9, 0.06, 1.3), Color = cover, Material = Enum.Material.Fabric, CFrame = CFrame.new(0, 0.03, 0), Parent = m })
	part({ Name = "PageL", Size = Vector3.new(0.88, 0.08, 1.2), Color = paper, Material = Enum.Material.Fabric, CFrame = CFrame.new(-0.46, 0.09, 0) * CFrame.Angles(0, 0, math.rad(-4)), Parent = m })
	part({ Name = "PageR", Size = Vector3.new(0.88, 0.08, 1.2), Color = paper, Material = Enum.Material.Fabric, CFrame = CFrame.new(0.46, 0.09, 0) * CFrame.Angles(0, 0, math.rad(4)), Parent = m })
	-- handwritten rows (names and amounts, not readable at this size: it's the look that matters)
	for i = 0, 5 do
		local z = -0.45 + i * 0.18
		part({ Name = "InkL" .. i, Size = Vector3.new(0.6, 0.01, 0.025), Color = Color3.fromRGB(40, 50, 90), CFrame = CFrame.new(-0.48, 0.135 + 0.002 * i, z) * CFrame.Angles(0, 0, math.rad(-4)), Parent = m })
		part({ Name = "InkR" .. i, Size = Vector3.new(0.4 + (i % 3) * 0.1, 0.01, 0.025), Color = Color3.fromRGB(40, 50, 90), CFrame = CFrame.new(0.42, 0.135 + 0.002 * i, z) * CFrame.Angles(0, 0, math.rad(4)), Parent = m })
	end
	part({ Name = "Pen", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.9, 0.06, 0.06), Color = Color3.fromRGB(20, 20, 24), CFrame = CFrame.new(0.5, 0.17, 0.25) * CFrame.Angles(0, math.rad(30), 0), Parent = m })
	m.PrimaryPart = base
	return m
end)

-- A standing photo frame by the register: teenage Dre in a Food Mart polo (Act 1 plant, nobody mentions it).
-- The picture is the real Dre rig, rendered small and young in a ViewportFrame on the frame's face.
Actors.registerProp("DrePhoto", function(): Model
	local m = Instance.new("Model")
	m.Name = "DrePhoto"
	local base = part({ Name = "Base", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CFrame = CFrame.new(0, 0, 0), Parent = m })
	local frame = part({ Name = "Frame", Size = Vector3.new(0.9, 1.15, 0.08), Color = Color3.fromRGB(46, 34, 26), Material = Enum.Material.Wood, CFrame = CFrame.new(0, 0.6, 0) * CFrame.Angles(math.rad(-10), 0, 0), Parent = m })
	part({ Name = "Stand", Size = Vector3.new(0.12, 0.9, 0.05), Color = Color3.fromRGB(46, 34, 26), CFrame = CFrame.new(0, 0.45, 0.25) * CFrame.Angles(math.rad(25), 0, 0), Parent = m })
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.CanvasSize = Vector2.new(180, 230)
	sg.LightInfluence = 1
	sg.Parent = frame
	local mat = Instance.new("Frame")
	mat.Size = UDim2.fromScale(1, 1)
	mat.BackgroundColor3 = Color3.fromRGB(226, 220, 204)
	mat.BorderSizePixel = 0
	mat.Parent = sg
	local vp = Instance.new("ViewportFrame")
	vp.Position = UDim2.fromOffset(14, 14)
	vp.Size = UDim2.new(1, -28, 1, -28)
	vp.BackgroundColor3 = Color3.fromRGB(150, 182, 160) -- a faded photo-studio green
	vp.Ambient = Color3.fromRGB(200, 196, 190)
	vp.LightColor = Color3.fromRGB(255, 240, 220)
	vp.Parent = mat
	local t = template("Dre", false)
	if t then
		local was = t.Archivable
		t.Archivable = true
		local kid = t:Clone()
		t.Archivable = was
		strip(kid)
		pcall(function()
			kid:ScaleTo(0.82) -- younger
		end)
		-- the Food Mart polo: green shirt, no jacket
		for _, d in kid:GetDescendants() do
			if d:IsA("Shirt") then
				d:Destroy()
			elseif d:IsA("BasePart") and (d.Name:find("Torso") or d.Name:find("UpperArm")) then
				d.Color = Color3.fromRGB(46, 128, 72)
			end
		end
		kid:PivotTo(CFrame.new())
		kid.Parent = vp
		local head = kid:FindFirstChild("Head") :: BasePart?
		local cam = Instance.new("Camera")
		cam.FieldOfView = 30
		local focus = if head then head.Position - Vector3.new(0, 0.6, 0) else Vector3.new(0, 1.5, 0)
		cam.CFrame = CFrame.lookAt(focus + Vector3.new(0, 0.2, -6), focus) -- rigs face -Z: look at the front
		cam.Parent = vp
		vp.CurrentCamera = cam
	end
	m.PrimaryPart = base
	return m
end)

-- Act 2.1: the supplier's box truck (front = -Z, origin at the floor, centred). The roll-up door at the back is open.
-- Alex: a model named DeliveryTruck in MTL_Actors replaces it.
Actors.registerProp("DeliveryTruck", function(opts: any): Model
	local m = Instance.new("Model")
	m.Name = "DeliveryTruck"
	local base = part({ Name = "Base", Size = Vector3.new(7.6, 0.2, 21), Transparency = 1, CFrame = CFrame.new(0, 0.1, 0), Parent = m })
	local white = Color3.fromRGB(232, 232, 228)
	local cabCol = Color3.fromRGB(196, 44, 40)
	local dark = Color3.fromRGB(26, 27, 31)
	-- chassis + bumpers
	part({ Name = "Chassis", Size = Vector3.new(6.6, 1, 20), Color = dark, Material = Enum.Material.Metal, CFrame = CFrame.new(0, 1.9, 0), Parent = m })
	part({ Name = "BumperF", Size = Vector3.new(7.4, 0.8, 0.5), Color = Color3.fromRGB(160, 162, 166), Material = Enum.Material.Metal, CFrame = CFrame.new(0, 1.6, -10.3), Parent = m })
	part({ Name = "BumperR", Size = Vector3.new(7.4, 0.5, 0.6), Color = dark, Material = Enum.Material.DiamondPlate, CFrame = CFrame.new(0, 1.6, 10.3), Parent = m })
	-- cab
	part({ Name = "Cab", Size = Vector3.new(7.4, 4.2, 5.2), Color = cabCol, Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(0, 4.4, -7.4), Parent = m })
	part({ Name = "Hood", Size = Vector3.new(7.2, 1.8, 1.6), Color = cabCol, Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(0, 3.2, -9.9), Parent = m })
	part({ Name = "Windshield", Size = Vector3.new(6.8, 2.2, 0.1), Color = Color3.fromRGB(30, 38, 50), Material = Enum.Material.Glass, Transparency = 0.2, CFrame = CFrame.new(0, 5.4, -10.0) * CFrame.Angles(math.rad(-12), 0, 0), Parent = m })
	for _, x in { -3.72, 3.72 } do
		part({ Name = "SideWindow", Size = Vector3.new(0.1, 1.8, 2.4), Color = Color3.fromRGB(30, 38, 50), Material = Enum.Material.Glass, Transparency = 0.2, CFrame = CFrame.new(x, 5.4, -8.4), Parent = m })
		part({ Name = "Mirror", Size = Vector3.new(0.2, 1.1, 0.5), Color = dark, CFrame = CFrame.new(x * 1.1, 5.2, -9.4), Parent = m })
	end
	part({ Name = "Grille", Size = Vector3.new(4.2, 1.2, 0.1), Color = dark, Material = Enum.Material.DiamondPlate, CFrame = CFrame.new(0, 2.9, -10.75), Parent = m })
	for _, x in { -2.9, 2.9 } do
		part({ Name = "Headlight", Size = Vector3.new(1, 0.6, 0.1), Color = Color3.fromRGB(255, 248, 225), Material = Enum.Material.Neon, CFrame = CFrame.new(x, 3, -10.75), Parent = m })
		part({ Name = "Taillight", Size = Vector3.new(0.5, 1.1, 0.1), Color = Color3.fromRGB(200, 20, 30), Material = Enum.Material.Neon, CFrame = CFrame.new(x * 1.2, 2.6, 10.62), Parent = m })
	end
	local lamp = Instance.new("SpotLight")
	lamp.Face = Enum.NormalId.Front
	lamp.Brightness = 2
	lamp.Range = 40
	lamp.Angle = 70
	lamp.Color = Color3.fromRGB(255, 244, 220)
	lamp.Parent = m:FindFirstChild("Grille")
	-- the box: three walls, a roof, a floor, and the dark load space you can see into through the open back
	local boxL, boxZ = 14.6, 2.6
	part({ Name = "BoxFloor", Size = Vector3.new(7.4, 0.3, boxL), Color = Color3.fromRGB(90, 80, 70), Material = Enum.Material.WoodPlanks, CFrame = CFrame.new(0, 2.55, boxZ), Parent = m })
	part({ Name = "BoxRoof", Size = Vector3.new(7.6, 0.3, boxL + 0.2), Color = white, Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(0, 10.6, boxZ), Parent = m })
	part({ Name = "BoxFront", Size = Vector3.new(7.6, 8.2, 0.3), Color = white, Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(0, 6.55, boxZ - boxL / 2), Parent = m })
	local sides = {}
	for i, x in { -3.7, 3.7 } do
		sides[i] = part({ Name = "BoxSide", Size = Vector3.new(0.3, 8.2, boxL), Color = white, Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(x, 6.55, boxZ), Parent = m })
		part({ Name = "Inner", Size = Vector3.new(0.05, 7.8, boxL - 0.4), Color = Color3.fromRGB(60, 56, 52), Material = Enum.Material.Metal, CFrame = CFrame.new(x * 0.95, 6.55, boxZ), Parent = m })
	end
	part({ Name = "RollDoor", Size = Vector3.new(7.2, 1.2, 0.3), Color = Color3.fromRGB(200, 200, 196), Material = Enum.Material.CorrodedMetal, CFrame = CFrame.new(0, 9.9, boxZ + boxL / 2 - 0.1), Parent = m })
	local inside = Instance.new("PointLight")
	inside.Brightness = 0.6
	inside.Range = 9
	inside.Color = Color3.fromRGB(255, 226, 180)
	inside.Parent = m:FindFirstChild("BoxRoof")
	-- the supplier's name down both sides
	for i, side in sides do
		local sg = Instance.new("SurfaceGui")
		sg.Face = if i == 1 then Enum.NormalId.Left else Enum.NormalId.Right
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 40
		sg.LightInfluence = 1
		sg.Parent = side
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(0.86, 0.34)
		t.Position = UDim2.fromScale(0.07, 0.24)
		t.Text = opts.text or "GULFSIDE WHOLESALE"
		t.TextScaled = true
		t.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
		t.TextColor3 = Color3.fromRGB(30, 70, 140)
		t.Parent = sg
		local sub = t:Clone()
		sub.Size = UDim2.fromScale(0.6, 0.14)
		sub.Position = UDim2.fromScale(0.2, 0.6)
		sub.Text = "FOOD SERVICE · SINCE 1987"
		sub.TextColor3 = Color3.fromRGB(196, 44, 40)
		sub.Parent = sg
	end
	-- wheels (dual at the back)
	for _, z in { -7.2, 6.4 } do
		for _, x in { -3.3, 3.3 } do
			part({ Name = "Wheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(if z > 0 then 1.4 else 1, 3, 3), Color = Color3.fromRGB(18, 18, 20), CFrame = CFrame.new(x, 1.5, z), Parent = m })
			part({ Name = "Hub", Shape = Enum.PartType.Cylinder, Size = Vector3.new(if z > 0 then 1.45 else 1.05, 1.3, 1.3), Color = Color3.fromRGB(170, 172, 176), Material = Enum.Material.Metal, CFrame = CFrame.new(x, 1.5, z), Parent = m })
		end
	end
	m.PrimaryPart = base
	return m
end)

-- A wooden pallet stacked with taped boxes (origin at the floor). opts.boxes = how many (default 9; 3 per layer
-- row, rows of 3). Act 2.1: the half the driver takes back.
Actors.registerProp("Pallet", function(opts: any): Model
	local m = Instance.new("Model")
	m.Name = "Pallet"
	local base = part({ Name = "Base", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CFrame = CFrame.new(0, 0, 0), Parent = m })
	local wood = Color3.fromRGB(176, 140, 96)
	for i = -1, 1 do
		part({ Name = "Runner", Size = Vector3.new(0.4, 0.35, 4), Color = wood, Material = Enum.Material.Wood, CFrame = CFrame.new(i * 1.8, 0.18, 0), Parent = m })
	end
	for i = -2, 2 do
		part({ Name = "Slat", Size = Vector3.new(4, 0.12, 0.6), Color = wood, Material = Enum.Material.Wood, CFrame = CFrame.new(0, 0.41, i * 0.85), Parent = m })
	end
	local n = opts.boxes or 9
	local k = 0
	for layer = 0, 2 do
		for row = -1, 1 do
			for col = 0, 1 do
				if k >= n then
					break
				end
				k += 1
				local shade = 150 + ((k * 37) % 20)
				local b = part({ Name = "Box", Size = Vector3.new(1.85, 1.3, 1.25), Color = Color3.fromRGB(shade, shade - 40, shade - 85), Material = Enum.Material.Cardboard, CFrame = CFrame.new(-0.95 + col * 1.9, 1.15 + layer * 1.32, row * 1.3), Parent = m })
				part({ Name = "Tape", Size = Vector3.new(1.86, 1.31, 0.18), Color = Color3.fromRGB(196, 170, 120), Material = Enum.Material.SmoothPlastic, CFrame = b.CFrame, Parent = m })
			end
		end
	end
	m.PrimaryPart = base
	return m
end)

-- Royce's business card lying on the counter (origin = the surface). "When you're tired, Hemant." on the back.
Actors.registerProp("BusinessCard", function(): Model
	local m = Instance.new("Model")
	m.Name = "BusinessCard"
	local base = part({ Name = "Base", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CFrame = CFrame.new(0, 0, 0), Parent = m })
	local card = part({ Name = "Card", Size = Vector3.new(0.9, 0.02, 0.52), Color = Color3.fromRGB(244, 240, 230), Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(0, 0.012, 0), Parent = m })
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Top
	sg.CanvasSize = Vector2.new(360, 208)
	sg.LightInfluence = 1
	sg.Parent = card
	local function label(text: string, y: number, h: number, weight: Enum.FontWeight, col: Color3, italic: boolean?)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, -40, 0, h)
		t.Position = UDim2.fromOffset(20, y)
		t.Text = text
		t.TextScaled = true
		t.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", weight, if italic then Enum.FontStyle.Italic else Enum.FontStyle.Normal)
		t.TextColor3 = col
		t.Parent = sg
	end
	label("ROYCE PROPERTIES", 34, 40, Enum.FontWeight.Heavy, Color3.fromRGB(150, 118, 50))
	label("Lionel Royce", 84, 26, Enum.FontWeight.Medium, Color3.fromRGB(40, 40, 44))
	label("\"When you're tired, Hemant.\"", 138, 30, Enum.FontWeight.Regular, Color3.fromRGB(40, 50, 90), true)
	m.PrimaryPart = base
	return m
end)

-- A mango soda can standing on the counter (origin = the surface).
Actors.registerProp("SodaCan", function(): Model
	local m = Instance.new("Model")
	m.Name = "SodaCan"
	local base = part({ Name = "Base", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CFrame = CFrame.new(0, 0, 0), Parent = m })
	part({ Name = "Can", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.78, 0.44, 0.44), Color = Color3.fromRGB(255, 150, 40), Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(0, 0.39, 0) * CFrame.Angles(0, 0, math.rad(90)), Parent = m })
	part({ Name = "Label", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.34, 0.46, 0.46), Color = Color3.fromRGB(70, 160, 60), Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(0, 0.42, 0) * CFrame.Angles(0, 0, math.rad(90)), Parent = m })
	m.PrimaryPart = base
	return m
end)

-- A cash envelope (origin = the surface). Act 2.3 payments, Act 2.7 "pay it, say nothing".
Actors.registerProp("Envelope", function(opts: any): Model
	local m = Instance.new("Model")
	m.Name = "Envelope"
	local base = part({ Name = "Base", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CFrame = CFrame.new(0, 0, 0), Parent = m })
	part({ Name = "Paper", Size = Vector3.new(1.0, 0.1, 0.55), Color = Color3.fromRGB(226, 208, 170), Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(0, 0.05, 0), Parent = m })
	part({ Name = "Cash", Size = Vector3.new(0.7, 0.04, 0.3), Color = Color3.fromRGB(150, 190, 140), Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(0.2, 0.11, 0), Parent = m })
	m.PrimaryPart = base
	return m
end)

-- A prop by name: a template in ReplicatedStorage.MTL_Actors wins over the built-in placeholder.
function Actors.prop(name: string, opts: any?): Model?
	local t = template(name)
	local m: Model? = nil
	if t then
		local was = t.Archivable
		t.Archivable = true
		m = t:Clone()
		t.Archivable = was
		for _, d in (m :: Model):GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
			end
		end
	elseif propBuilders[name] then
		m = propBuilders[name](opts or {})
	end
	if not m then
		warn("[MTL Cutscene] unknown prop", name)
		return nil
	end
	strip(m)
	m.Parent = (opts and opts.parent) or folder()
	if opts and opts.hazards then
		Actors.hazards(m, true)
	end
	return m
end

-- Blinking hazard lights on a car prop (parts named "Hazard" + a light named "HazardLight").
function Actors.hazards(m: Model, on: boolean)
	m:SetAttribute("MTL_Hazards", on)
	if not on or m:GetAttribute("MTL_HazardLoop") then
		return
	end
	m:SetAttribute("MTL_HazardLoop", true)
	task.spawn(function()
		while m.Parent and m:GetAttribute("MTL_Hazards") do
			local lit = (os.clock() * 1.4) % 1 < 0.5
			for _, d in m:GetDescendants() do
				if d.Name == "Hazard" and d:IsA("BasePart") then
					d.Transparency = if lit then 0 else 0.6
				elseif d.Name == "HazardLight" and d:IsA("Light") then
					d.Brightness = if lit then 2 else 0
				end
			end
			RunService.Heartbeat:Wait()
		end
		if m.Parent then
			m:SetAttribute("MTL_HazardLoop", nil)
		end
	end)
end

return Actors
