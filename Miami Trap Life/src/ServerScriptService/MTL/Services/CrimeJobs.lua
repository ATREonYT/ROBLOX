--!strict
-- The six repeatable crimes (Config/Crime.Methods), on top of CrimeService (prompts, minigames, dirty cash, stacks)
-- and PoliceService (heat). Story rule: only Royce's places.
--   Stickup   aim at the clerk -> hands up, alarm, 1 star -> grab the drawer stacks -> get away
--   TipJob    Dre texts a wall -> 3 sledgehammer hits (timing) -> the wall gives, 2 stars -> scoop the stash
--   HouseLick pry the back door of a 52nd St rental -> inside (instanced room) -> carry the goods to Smoke's van one at
--             a time -> the van leaves -> Marcus pays for the goods at the Cash 4 Gold back door. 1 star after 40 s
--   CarBoost  Royce's collector parks his ride -> slim jim (timing) -> alarm, 2 stars -> drive it to A1 Tires; damage
--             costs you
--   AtmDrill  bolt the rig on an ATM (hold) -> 45 s of loud drilling you have to stay near -> the box pops -> stacks
--   Heist     Cash 4 Gold after close, with a crew: pry in, cut the alarm, crack the safe, carry 4 bags to the crew car,
--             the take is split. 3 stars
-- Every run is { id, method, site, players, prompts, parts, cleanup, ... } in CrimeService.runs[player].
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local Crime = require(ReplicatedStorage.MTL.Config.Crime)
local CrimeRules = require(ReplicatedStorage.MTL.Rules.CrimeRules)
local Rig = require(ReplicatedStorage.MTL.Rig)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local Notify = require(script.Parent.Notify)
local PoliceService = require(script.Parent.PoliceService)

local CrimeJobs = {}

local C: any = nil -- CrimeService (set in init)
local rng = Random.new()
local runCounter = 0
local RED = Color3.fromRGB(226, 72, 72)

-- House rule (HUD thread): every refused action tells the player why, through Notify.refuse when it exists.
local function refuse(player: Player, text: string)
	local n = Notify :: any
	if n.refuse then
		n.refuse(player, text)
	else
		Notify.toast(player, text, Color3.fromRGB(226, 72, 72))
	end
end
local GREEN = Color3.fromRGB(92, 196, 104)

local function log(...)
	print("[MTL Crime]", ...)
end

local function sibling(name: string): any?
	return C.sibling(name)
end

local function waypoints(): any?
	return sibling("WaypointService")
end

local function setWaypoint(player: Player, id: string, pos: Vector3, label: string, radius: number?)
	local w = waypoints()
	if w then
		pcall(w.set, player, id, pos, { label = label, radius = radius or 10, breadcrumbs = true })
	end
end

local function clearWaypoint(player: Player, id: string)
	local w = waypoints()
	if w and w.clear then
		pcall(w.clear, player, id)
	end
end

local function objective(player: Player, text: string)
	Notify.objective(player, text)
end

local function propsLib(): Instance?
	return ServerStorage:FindFirstChild("MTL_CrimeProps")
end

local function prop(name: string): Model?
	local lib = propsLib()
	local t = lib and lib:FindFirstChild(name, true)
	if t and t:IsA("Model") then
		local m = t:Clone()
		for _, d in m:GetDescendants() do
			if d:IsA("BaseScript") then
				d:Destroy()
			end
		end
		return m
	end
	return nil
end

local function giveXP(player: Player, amount: number, reason: string, at: Vector3?)
	pcall(EconomyService.addXP, player, amount, reason, at)
end

local function stat(player: Player)
	local data = DataService.get(player)
	if data and data.Stats then
		data.Stats.Robberies = (data.Stats.Robberies or 0) + 1
	end
end

---------------------------------------------------------------- runs

local function newRun(method: string, site: string, players: { Player }): any
	runCounter += 1
	local run = {
		id = method .. "#" .. runCounter,
		method = method,
		site = site,
		players = players,
		leader = players[1],
		prompts = {},
		parts = {},
		cleanup = {},
		started = os.clock(),
		over = false,
	}
	for _, p in players do
		C.runs[p] = run
	end
	return run
end

local function touch(run: any)
	C.touchPrompts(run.players)
end

local function addPrompt(run: any, e: any)
	run.prompts[e.id] = e
	touch(run)
end

local function removePrompt(run: any, id: string)
	if run.prompts[id] then
		run.prompts[id] = nil
		touch(run)
	end
end

local function endRun(run: any, reason: string?)
	if run.over then
		return
	end
	run.over = true
	for _, fn in run.cleanup do
		pcall(fn)
	end
	for _, part in run.parts do
		if typeof(part) == "Instance" and part.Parent then
			part:Destroy()
		end
	end
	for _, p in run.players do
		if C.runs[p] == run then
			C.runs[p] = nil
		end
		C.cancelMini(p)
		C.send(p, { type = "runEnd", method = run.method, reason = reason })
	end
	touch(run)
	log(run.id, "ended", reason or "")
end

local function inRun(player: Player, method: string): any?
	local run = C.runs[player]
	return if run and run.method == method and not run.over then run else nil
end

local function fadeTo(player: Player, cf: CFrame)
	C.send(player, { type = "fade" })
	task.delay(0.3, function()
		local r = C.root(player)
		if r then
			r.CFrame = cf + Vector3.new(0, 3, 0)
			r.AssemblyLinearVelocity = Vector3.zero
		end
	end)
end

---------------------------------------------------------------- carrying (ActionPose reads character.MTL_Carry + Pose)

local carrying: { [Player]: { kind: string, value: number, model: Model, speed: number? } } = {}

local function lootModel(look: string): Model
	local m = prop("Loot_" .. look)
	if m then
		return m
	end
	-- a simple stand-in per kind, sized like the real thing
	m = Instance.new("Model")
	local sizes = {
		TV = Vector3.new(3.2, 1.9, 0.3),
		Speaker = Vector3.new(1.1, 1.8, 1.1),
		Console = Vector3.new(1.4, 0.35, 1.1),
		Laptop = Vector3.new(1.3, 0.12, 0.95),
		Microwave = Vector3.new(1.8, 1.05, 1.2),
		Jewelry = Vector3.new(0.9, 0.55, 0.6),
	}
	local colors = {
		TV = Color3.fromRGB(18, 18, 20),
		Speaker = Color3.fromRGB(26, 26, 30),
		Console = Color3.fromRGB(235, 235, 238),
		Laptop = Color3.fromRGB(150, 150, 158),
		Microwave = Color3.fromRGB(220, 220, 224),
		Jewelry = Color3.fromRGB(96, 30, 44),
	}
	local p = Instance.new("Part")
	p.Name = "Body"
	p.Size = sizes[look] or Vector3.new(1.2, 1, 1)
	p.Color = colors[look] or Color3.fromRGB(120, 120, 120)
	p.Material = if look == "Jewelry" then Enum.Material.Fabric else Enum.Material.SmoothPlastic
	p.Parent = m
	if look == "TV" then
		local screen = Instance.new("Part")
		screen.Name = "Screen"
		screen.Size = Vector3.new(3.0, 1.7, 0.05)
		screen.Color = Color3.fromRGB(10, 14, 22)
		screen.Material = Enum.Material.Glass
		screen.CFrame = p.CFrame * CFrame.new(0, 0, -0.16)
		screen.Parent = m
	elseif look == "Speaker" then
		for i, y in { 0.45, -0.3 } do
			local cone = Instance.new("Part")
			cone.Name = "Cone" .. i
			cone.Shape = Enum.PartType.Cylinder
			cone.Size = Vector3.new(0.06, if i == 1 then 0.5 else 0.8, if i == 1 then 0.5 else 0.8)
			cone.Color = Color3.fromRGB(60, 60, 66)
			cone.CFrame = p.CFrame * CFrame.new(0, y, -0.56) * CFrame.Angles(0, math.rad(90), 0)
			cone.Parent = m
		end
	elseif look == "Microwave" then
		local door = Instance.new("Part")
		door.Name = "Door"
		door.Size = Vector3.new(1.2, 0.8, 0.05)
		door.Color = Color3.fromRGB(20, 20, 24)
		door.Material = Enum.Material.Glass
		door.CFrame = p.CFrame * CFrame.new(-0.2, 0, -0.61)
		door.Parent = m
	elseif look == "Jewelry" then
		local lid = Instance.new("Part")
		lid.Name = "Clasp"
		lid.Size = Vector3.new(0.16, 0.12, 0.05)
		lid.Color = Color3.fromRGB(226, 196, 120)
		lid.Material = Enum.Material.Metal
		lid.CFrame = p.CFrame * CFrame.new(0, 0.12, -0.31)
		lid.Parent = m
	end
	m.PrimaryPart = p
	return m
end

local function setCarry(player: Player, kind: string, value: number, model: Model, pose: string)
	local char = player.Character
	local torso = char and (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")) :: BasePart?
	local hum = C.humanoid(player)
	if not char or not torso or not hum then
		model:Destroy()
		return
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		end
	end
	local offset = if pose == "Side" then CFrame.new(1.35, -1.1, 0) else CFrame.new(0, -0.35, -1.05)
	model:PivotTo(torso.CFrame * offset)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local w = Instance.new("WeldConstraint")
			w.Part0 = torso
			w.Part1 = d
			w.Parent = d
		end
	end
	model.Name = "MTL_Carry"
	model:SetAttribute("Pose", pose)
	model.Parent = char
	local prev = hum.WalkSpeed
	hum.WalkSpeed = math.min(prev, 14)
	carrying[player] = { kind = kind, value = value, model = model, speed = prev }
end

local function dropCarry(player: Player): (string?, number)
	local c = carrying[player]
	if not c then
		return nil, 0
	end
	carrying[player] = nil
	if c.model.Parent then
		c.model:Destroy()
	end
	local hum = C.humanoid(player)
	if hum and c.speed then
		hum.WalkSpeed = c.speed
	end
	return c.kind, c.value
end
CrimeJobs.dropCarry = dropCarry

---------------------------------------------------------------- shared: grab-the-stacks

-- Lays stacks on `surface` and gives every run member a "Grab" prompt per stack. onEmpty() when the last one goes.
local function stacksFor(run: any, surface: CFrame, values: { number }, grabSeconds: number, onEmpty: () -> ())
	local folder = Instance.new("Folder")
	folder.Name = "Stacks_" .. run.id
	folder.Parent = workspace
	table.insert(run.parts, folder)
	local list = C.layStacks(folder, surface, values)
	local left = #list
	for i, s in list do
		local id = run.id .. ":stack" .. i
		addPrompt(run, {
			id = id,
			pos = s.cf.Position + Vector3.new(0, 0.3, 0),
			action = "Grab",
			object = CrimeRules.money(s.value),
			hold = grabSeconds,
			range = 7,
			style = "cash",
			pose = "Grab", -- ActionPose: hands into the drawer while you hold
			fn = function(player: Player)
				if not s.model.Parent then
					return
				end
				s.model:Destroy()
				removePrompt(run, id)
				C.addDirty(player, s.value, run.method, s.cf.Position)
				C.sound(Crime.Sounds.CashGrab, s.cf.Position, { volume = 0.6 })
				left -= 1
				if left <= 0 then
					onEmpty()
				end
			end,
		})
	end
end

---------------------------------------------------------------- Stickup

local clerks: { [string]: { model: Model, joints: any, scared: boolean } } = {}
local busySite: { [string]: boolean } = {}
local stickupDenied: { [Player]: number } = {}

local function spawnClerks()
	for site, actor in Crime.Clerks do
		local at = C.point(site, "Clerk")
		local look = Crime.Actors[actor]
		if at and look then
			local m = C.buildRig("MTL_Clerk_" .. site, look)
			if m then
				C.placeRig(m, at, C.npcFolder())
				m:SetAttribute("MTL_CrimeSite", site)
				CollectionService:AddTag(m, "MTL_Intimidate")
				clerks[site] = { model = m, joints = Rig.joints(m), scared = false }
			end
		else
			warn("[MTL Crime] no clerk point for", site, "(run tools/BuildCrimeSites.lua)")
		end
	end
end

local function scare(site: string, player: Player)
	local c = clerks[site]
	if not c then
		return
	end
	if not c.scared then
		c.scared = true
		Rig.apply(c.joints, Rig.compose({ pose = "HandsUp", poseT0 = -10, breath = false }, 0), "C0")
	end
	local r = c.model.PrimaryPart
	local pr = C.root(player)
	if r and pr then
		local look = Vector3.new(pr.Position.X, r.Position.Y, pr.Position.Z)
		if (look - r.Position).Magnitude > 0.5 then
			r.CFrame = CFrame.lookAt(r.Position, look)
		end
	end
end

local function calm(site: string)
	local c = clerks[site]
	if c and c.scared then
		c.scared = false
		Rig.reset(c.joints, "C0")
		local at = C.point(site, "Clerk")
		local r = c.model.PrimaryPart
		if at and r then
			r.CFrame = CFrame.new(r.Position) * at.Rotation
		end
	end
end

local function startStickup(player: Player, site: string)
	local m = Crime.Methods.Stickup
	busySite[site] = true
	local run = newRun("Stickup", site, { player })
	C.markDone(player, "Stickup", "Stickup:" .. site)
	scare(site, player)
	local clerkAt = C.point(site, "Clerk")
	local alarmAt = if clerkAt then clerkAt.Position + Vector3.new(0, 6, 0) else C.siteAt(site)
	local alarm = C.sound(Crime.Sounds.Alarm, alarmAt, { looped = true, volume = 0.7, max = 260, life = 30 })
	PoliceService.raise(player, m.heat, "stickup")
	objective(player, "Empty the drawer")
	C.send(player, { type = "runStart", method = "Stickup", title = "Stickup", site = site })
	local drawer = C.point(site, "Drawer") or (if clerkAt then clerkAt * CFrame.new(0, 3.1, -1.6) else CFrame.new(C.siteAt(site)))
	-- the drawer pops open: a till tray on the counter
	local tray = Instance.new("Part")
	tray.Name = "Till"
	tray.Size = Vector3.new(2.3, 0.2, 1.2)
	tray.Color = Color3.fromRGB(40, 40, 44)
	tray.Material = Enum.Material.Metal
	tray.Anchored = true
	tray.CanCollide = false
	tray.CFrame = drawer * CFrame.new(0, -0.1, 0)
	tray.Parent = workspace
	table.insert(run.parts, tray)
	table.insert(run.cleanup, function()
		if alarm then
			task.delay(12, function()
				alarm:Destroy()
			end)
		end
		task.delay(20, function()
			busySite[site] = nil
			calm(site)
		end)
	end)
	local values = CrimeRules.rollStacks(rng, m.stacks, m.stackValue)
	stacksFor(run, drawer, values, m.grabSeconds, function()
		giveXP(player, m.xp, "Stickup", drawer.Position)
		stat(player)
		C.Done:Fire(player, "Stickup", 0)
		objective(player, "Get away. Break their line of sight.")
		endRun(run, "done")
	end)
	-- walked off or took too long: the drawer slams
	task.spawn(function()
		while not run.over do
			task.wait(0.5)
			local r = C.root(player)
			local h = C.humanoid(player)
			if not r or not h or h.Health <= 0 or (r.Position - drawer.Position).Magnitude > 60 or os.clock() - run.started > 75 then
				if not run.over then
					endRun(run, "left")
				end
			end
		end
	end)
	log(player.Name, "stickup at", site)
end

local function onIntimidating(player: Player, target: Instance, held: number)
	if not target or not target:IsA("Model") then
		return
	end
	local site = target:GetAttribute("MTL_CrimeSite")
	local m = Crime.Methods.Stickup
	if type(site) ~= "string" or not table.find(m.sites, site) then
		return
	end
	if busySite[site] or C.runs[player] then
		return
	end
	if held < m.aimSeconds then
		C.send(player, { type = "aim", t = held / m.aimSeconds, label = "Hands where I can see them" })
		scare(site, player) -- the clerk flinches up straight away
		return
	end
	local ok, why = C.canDo(player, "Stickup", "Stickup:" .. site)
	if not ok then
		if os.clock() - (stickupDenied[player] or 0) > 5 then
			stickupDenied[player] = os.clock()
			refuse(player, why or "Not now")
		end
		task.delay(3, function()
			if not busySite[site] then
				calm(site)
			end
		end)
		return
	end
	startStickup(player, site)
end

---------------------------------------------------------------- TipJob

local tips: { [Player]: { spot: string, expires: number } } = {}
local wallsDown: { [string]: number } = {} -- spot -> os.clock() it can be rebuilt

local function spotTitle(id: string): string
	local s = (Crime.Sites :: any)[id]
	local site = C.site(id)
	local t = site and site:GetAttribute("Title")
	return if type(t) == "string" then t elseif s then s.title else id
end

local function wallPart(spot: string): Instance?
	local site = C.site(spot)
	return site and site:FindFirstChild("Wall")
end

local function setWall(spot: string, up: boolean)
	local w = wallPart(spot)
	if not w then
		return
	end
	local parts = if w:IsA("BasePart") then { w } else w:GetDescendants()
	for _, p in parts do
		if p:IsA("BasePart") then
			if p:GetAttribute("T0") == nil then
				p:SetAttribute("T0", p.Transparency)
			end
			p.Transparency = if up then p:GetAttribute("T0") :: number else 1
			p.CanCollide = up
			p.CanQuery = up
		end
	end
	local holeArt = C.site(spot) and (C.site(spot) :: Instance):FindFirstChild("Hole")
	if holeArt then
		for _, p in (if holeArt:IsA("BasePart") then { holeArt } else holeArt:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Transparency = if up then 1 else 0
			end
		end
	end
end

local function debris(at: CFrame, color: Color3, n: number)
	for _ = 1, n do
		local p = Instance.new("Part")
		p.Size = Vector3.new(rng:NextNumber(0.3, 0.9), rng:NextNumber(0.25, 0.6), rng:NextNumber(0.3, 0.8))
		p.Color = color
		p.Material = Enum.Material.Concrete
		p.CFrame = at * CFrame.new(rng:NextNumber(-1.5, 1.5), rng:NextNumber(-1, 1.5), 0)
		p.CanCollide = true
		p.Parent = workspace
		p.AssemblyLinearVelocity = (at.LookVector * -rng:NextNumber(8, 18)) + Vector3.new(rng:NextNumber(-4, 4), rng:NextNumber(4, 10), rng:NextNumber(-4, 4))
		task.delay(6, function()
			p:Destroy()
		end)
	end
end

local function tipPrompt(player: Player, spot: string)
	local wall = C.point(spot, "Swing")
	if not wall then
		return
	end
	C.setPlayerPrompt(player, {
		id = "tip:" .. spot,
		pos = wall.Position,
		action = "Break the wall",
		object = "Sledgehammer",
		hold = 0,
		range = 7,
		fn = function(p: Player)
			CrimeJobs.swingWall(p, spot)
		end,
	})
end

local function sendTip(player: Player)
	local m = Crime.Methods.TipJob
	local free = {}
	for _, s in m.spots do
		if C.point(s, "Swing") and not wallsDown[s] then
			local taken = false
			for _, t in tips do
				if t.spot == s then
					taken = true
				end
			end
			if not taken then
				table.insert(free, s)
			end
		end
	end
	if #free == 0 then
		return
	end
	local spot = free[rng:NextInteger(1, #free)]
	tips[player] = { spot = spot, expires = os.clock() + 600 }
	local text = m and Crime.Texts.TipJob[rng:NextInteger(1, #Crime.Texts.TipJob)]
	local phone = sibling("PhoneService")
	if phone then
		pcall(phone.text, player, "Dre", (string.gsub(text, "{spot}", spotTitle(spot))))
	end
	local at = C.point(spot, "Swing")
	if at then
		setWaypoint(player, "crime_tip", at.Position, "Tip: money in a wall", 8)
	end
	tipPrompt(player, spot)
	log(player.Name, "tip ->", spot)
end

function CrimeJobs.swingWall(player: Player, spot: string)
	local tip = tips[player]
	if not tip or tip.spot ~= spot then
		return
	end
	local ok, why = C.canDo(player, "TipJob", "TipJob")
	if not ok then
		refuse(player, why or "Not now")
		return
	end
	local m = Crime.Methods.TipJob
	local char = player.Character
	if char then
		char:SetAttribute("MTL_Action", "Hammer")
	end
	local swingAt = C.point(spot, "Swing") :: CFrame
	C.mini(player, "tip:" .. spot, { kind = "timing", hits = m.hits, zone = 0.2, speed = 1.15, verb = "Swing", sound = "Smash" }, 1.6, function(p: Player, score: number)
		if char then
			char:SetAttribute("MTL_Action", nil)
		end
		if score < 0.34 then
			Notify.toast(p, "Bad swings. The wall held. Go again.", RED)
			C.sound(Crime.Sounds.Smash, swingAt.Position, { volume = 0.9 })
			return
		end
		if tips[p] == nil or tips[p].spot ~= spot then
			return
		end
		tips[p] = nil
		C.clearPlayerPrompt(p, "tip:" .. spot)
		clearWaypoint(p, "crime_tip")
		local run = newRun("TipJob", spot, { p })
		C.markDone(p, "TipJob", "TipJob")
		C.sound(Crime.Sounds.Break, swingAt.Position, { volume = 1, max = 300 })
		local w = wallPart(spot)
		local color = if w and w:IsA("BasePart") then w.Color else Color3.fromRGB(190, 180, 160)
		setWall(spot, false)
		debris(swingAt, color, 14)
		wallsDown[spot] = os.clock() + 180
		PoliceService.raise(p, m.heat, "tip job")
		objective(p, "Scoop the stash")
		C.send(p, { type = "runStart", method = "TipJob", title = "Tip job", site = spot })
		local stash = C.point(spot, "Stash") or swingAt * CFrame.new(0, -1.5, 1.5)
		local values = CrimeRules.rollStacks(rng, m.stacks, m.stackValue)
		stacksFor(run, stash, values, m.grabSeconds, function()
			giveXP(p, m.xp, "TipJob", stash.Position)
			stat(p)
			C.Done:Fire(p, "TipJob", 0)
			objective(p, "Get away. Break their line of sight.")
			endRun(run, "done")
		end)
		task.delay(90, function()
			if not run.over then
				endRun(run, "timeout")
			end
		end)
	end, function()
		if char then
			char:SetAttribute("MTL_Action", nil)
		end
	end)
end

---------------------------------------------------------------- HouseLick

local houseBusy: { [string]: any } = {}

local function lickPoint(site: string, name: string): CFrame?
	-- inside points live under MTL_CrimeSites.<site>.Room
	return C.point(site, name)
end

local function vanModel(): Model
	local m = prop("Van")
	if m then
		return m
	end
	m = Instance.new("Model")
	local function part(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = mat or Enum.Material.SmoothPlastic
		p.Parent = m
		return p
	end
	local white = Color3.fromRGB(226, 226, 222)
	local body = part("Body", Vector3.new(7, 6.4, 15), CFrame.new(0, 4.1, 0), white, Enum.Material.Metal)
	part("Cab", Vector3.new(6.8, 4.2, 3.2), CFrame.new(0, 3.2, -8.9), white, Enum.Material.Metal)
	part("Windshield", Vector3.new(6.2, 2.0, 0.2), CFrame.new(0, 4.4, -10.5) * CFrame.Angles(math.rad(-12), 0, 0), Color3.fromRGB(30, 36, 44), Enum.Material.Glass)
	part("Bumper", Vector3.new(7.2, 0.7, 0.6), CFrame.new(0, 1.3, 7.7), Color3.fromRGB(30, 30, 32))
	part("DoorL", Vector3.new(3.4, 5.6, 0.15), CFrame.new(-1.75, 4.1, 7.58), Color3.fromRGB(214, 214, 210), Enum.Material.Metal)
	part("DoorR", Vector3.new(3.4, 5.6, 0.15), CFrame.new(1.75, 4.1, 7.58), Color3.fromRGB(214, 214, 210), Enum.Material.Metal)
	part("Rust", Vector3.new(7.05, 0.6, 6), CFrame.new(0, 1.7, 2), Color3.fromRGB(140, 90, 60), Enum.Material.CorrodedMetal)
	for _, x in { -3.2, 3.2 } do
		for _, z in { -7.6, 4.8 } do
			local w = part("Wheel", Vector3.new(1.3, 2.8, 2.8), CFrame.new(x, 1.4, z), Color3.fromRGB(18, 18, 20))
			w.Shape = Enum.PartType.Cylinder
		end
	end
	m.PrimaryPart = body
	return m
end

local function anchorAll(m: Model)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
end

local function finishLick(run: any, sent: boolean)
	local player = run.leader
	local m = Crime.Methods.HouseLick
	if run.loaded > 0 then
		local c = C.data(player)
		if c then
			c.Fence += run.loaded
		end
		local fenceAt = C.point(Crime.FenceSite, "Fence")
		if fenceAt then
			setWaypoint(player, "crime_fence", fenceAt.Position, "Marcus: fence the goods", 10)
		end
		Notify.toast(player, "Smoke's got the goods. Marcus pays " .. CrimeRules.money(run.loaded) .. " at the Cash 4 Gold back door.", GREEN)
		giveXP(player, math.floor(m.xp * math.clamp(run.count / m.items, 0.3, 1)), "HouseLick")
		stat(player)
		C.Done:Fire(player, "HouseLick", run.loaded)
		objective(player, "Take the goods to Marcus")
	end
	-- the van pulls away
	local van = run.van :: Model?
	if van and van.Parent and sent then
		local body = van.PrimaryPart :: BasePart
		local start = van:GetPivot()
		local cv = Instance.new("CFrameValue")
		cv.Value = start
		cv.Changed:Connect(function(v)
			if van.Parent then
				van:PivotTo(v)
			end
		end)
		local t = TweenService:Create(cv, TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = start * CFrame.new(0, 0, -160) })
		t:Play()
		local _ = body
		table.remove(run.parts, table.find(run.parts, van) or 0)
		task.delay(5.2, function()
			van:Destroy()
			cv:Destroy()
		end)
	end
	dropCarry(player)
	endRun(run, if sent then "done" else "left")
end

local function startLick(player: Player, site: string)
	local m = Crime.Methods.HouseLick
	local back = C.point(site, "BackDoor") :: CFrame
	local entry = lickPoint(site, "Entry")
	if not entry then
		refuse(player, "This one's boarded up for now.")
		return
	end
	local run = newRun("HouseLick", site, { player })
	houseBusy[site] = run
	run.loaded = 0
	run.count = 0
	C.markDone(player, "HouseLick", "HouseLick:" .. site)
	C.sound(Crime.Sounds.Smash, back.Position, { volume = 1 })
	C.send(player, { type = "runStart", method = "HouseLick", title = "House lick", site = site, total = m.items })
	table.insert(run.cleanup, function()
		houseBusy[site] = nil
		clearWaypoint(player, "crime_van")
	end)
	-- Smoke's van backs up to the yard
	local vanAt = C.point(site, "Van")
	if vanAt then
		local van = vanModel()
		van.Name = "MTL_LickVan"
		anchorAll(van)
		van:PivotTo(vanAt)
		van.Parent = workspace
		run.van = van
		table.insert(run.parts, van)
	end
	-- loot in the room
	local kinds = {}
	for k in Crime.Loot do
		table.insert(kinds, k)
	end
	table.sort(kinds)
	local lootFolder = Instance.new("Folder")
	lootFolder.Name = "Loot_" .. run.id
	lootFolder.Parent = workspace
	table.insert(run.parts, lootFolder)
	for i = 1, m.items do
		local at = lickPoint(site, "Loot" .. i)
		if at then
			local kind = kinds[rng:NextInteger(1, #kinds)]
			local def = Crime.Loot[kind]
			local model = lootModel(def.look)
			anchorAll(model)
			local body = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart") :: BasePart
			model:PivotTo(at + Vector3.new(0, body.Size.Y / 2, 0))
			model.Parent = lootFolder
			local value = CrimeRules.roll(rng, def.value)
			local id = run.id .. ":loot" .. i
			addPrompt(run, {
				id = id,
				pos = at.Position + Vector3.new(0, body.Size.Y / 2, 0),
				action = "Take",
				object = def.title .. "  " .. CrimeRules.money(value),
				hold = 0.6,
				range = 7,
				fn = function(p: Player)
					if carrying[p] then
						Notify.toast(p, "Hands full. Take that one out to the van first.")
						return
					end
					if not model.Parent then
						return
					end
					removePrompt(run, id)
					model.Parent = nil
					setCarry(p, kind, value, model, def.carry or "Hug")
					objective(p, "Carry it out to the van")
				end,
			})
		end
	end
	-- doors both ways
	local exit = lickPoint(site, "Exit") or entry
	addPrompt(run, {
		id = run.id .. ":out",
		pos = exit.Position,
		action = "Go outside",
		object = "Back door",
		hold = 0,
		range = 7,
		fn = function(p: Player)
			fadeTo(p, back * CFrame.new(0, 0, -4))
		end,
	})
	addPrompt(run, {
		id = run.id .. ":in",
		pos = back.Position,
		action = "Go inside",
		object = "Back door",
		hold = 0,
		range = 7,
		fn = function(p: Player)
			fadeTo(p, entry)
		end,
	})
	if run.van then
		local rear = (run.van :: Model):GetPivot() * CFrame.new(0, 0, 9)
		setWaypoint(player, "crime_van", rear.Position, "Smoke's van", 8)
		addPrompt(run, {
			id = run.id .. ":load",
			pos = rear.Position + Vector3.new(0, 2, 0),
			action = "Load it",
			object = "Smoke's van",
			hold = 0.4,
			range = 9,
			fn = function(p: Player)
				local kind, value = dropCarry(p)
				if not kind then
					if run.count > 0 then
						finishLick(run, true)
					else
						Notify.toast(p, "Bring something out first.")
					end
					return
				end
				run.loaded += value
				run.count += 1
				C.sound(Crime.Sounds.Smash, rear.Position, { volume = 0.5, speed = 1.3 })
				C.send(p, { type = "runProgress", count = run.count, total = m.items, value = run.loaded })
				if run.count >= m.items then
					finishLick(run, true)
				else
					objective(p, string.format("Loaded %d of %d. Grab more, or load nothing to send the van", run.count, m.items))
				end
			end,
		})
	end
	fadeTo(player, entry)
	objective(player, "Grab what you can carry")
	-- a neighbour calls it in
	task.delay(m.heatDelay, function()
		if not run.over then
			PoliceService.raise(player, m.heat, "house lick")
			Notify.toast(player, "A neighbour called it in. Wrap it up.", RED)
		end
	end)
	-- time limit: 6 minutes, then Smoke leaves with whatever's in the van
	task.delay(360, function()
		if not run.over then
			finishLick(run, true)
		end
	end)
	log(player.Name, "house lick at", site)
end

---------------------------------------------------------------- CarBoost

local boosts: { [Player]: any } = {}

local function boostCar(spot: string): (Model?, VehicleSeat?)
	local m = Crime.Methods.CarBoost
	local folder = ServerStorage:FindFirstChild("MTL_Cars")
	local t = folder and folder:FindFirstChild(m.carTemplate)
	local at = C.point(spot, "Car")
	if not t or not at then
		return nil, nil
	end
	local car = (t :: Model):Clone()
	car.Name = "MTL_BoostCar"
	car:PivotTo(at + Vector3.new(0, 1, 0))
	car.Parent = workspace
	local seat = car:FindFirstChild("DriveSeat", true)
	if seat and seat:IsA("VehicleSeat") then
		seat.Disabled = true
		return car, seat
	end
	return car, nil
end

local function endBoost(player: Player, reason: string)
	local b = boosts[player]
	if not b then
		return
	end
	boosts[player] = nil
	C.clearPlayerPrompt(player, "boost:door")
	clearWaypoint(player, "crime_boost")
	clearWaypoint(player, "crime_chop")
	for _, conn in b.conns do
		conn:Disconnect()
	end
	if b.alarm then
		b.alarm:Destroy()
	end
	if b.run and not b.run.over then
		endRun(b.run, reason)
	end
	local car = b.car
	if car and car.Parent then
		task.delay(if reason == "done" then 0.5 else 20, function()
			if car.Parent then
				car:Destroy()
			end
		end)
	end
end

local function offerBoost(player: Player)
	local m = Crime.Methods.CarBoost
	local free = {}
	for _, s in m.spots do
		if C.point(s, "Car") then
			local taken = false
			for _, b in boosts do
				if b.spot == s then
					taken = true
				end
			end
			if not taken then
				table.insert(free, s)
			end
		end
	end
	if #free == 0 then
		return
	end
	local spot = free[rng:NextInteger(1, #free)]
	local car, seat = boostCar(spot)
	if not car then
		return
	end
	local b = { spot = spot, car = car, seat = seat, conns = {}, hits = 0, expires = os.clock() + 600, unlocked = false }
	boosts[player] = b
	local phone = sibling("PhoneService")
	if phone then
		pcall(phone.text, player, "Smoke", (string.gsub(Crime.Texts.Boost, "{spot}", spotTitle(spot))))
	end
	setWaypoint(player, "crime_boost", car:GetPivot().Position, "Royce's collector's ride", 12)
	-- the driver's door: left side of the car (A-Chassis faces -Z)
	local door = car:GetPivot() * CFrame.new(-4.5, 0, -1)
	C.setPlayerPrompt(player, {
		id = "boost:door",
		pos = door.Position + Vector3.new(0, 2, 0),
		action = "Slim jim the door",
		object = "Collector's ride",
		hold = 0,
		range = 7,
		fn = function(p: Player)
			CrimeJobs.jimmy(p)
		end,
	})
	log(player.Name, "boost ->", spot)
end

function CrimeJobs.jimmy(player: Player)
	local b = boosts[player]
	local m = Crime.Methods.CarBoost
	if not b or b.unlocked then
		return
	end
	local ok, why = C.canDo(player, "CarBoost", "CarBoost")
	if not ok then
		refuse(player, why or "Not now")
		return
	end
	local char = player.Character
	if char then
		char:SetAttribute("MTL_Action", "Pry")
	end
	C.mini(player, "boost", { kind = "timing", hits = m.hits, zone = 0.16, speed = 1.0, verb = "Pick" }, 2.0, function(p: Player, score: number)
		if char then
			char:SetAttribute("MTL_Action", nil)
		end
		if score < 0.5 then
			Notify.toast(p, "The lock fought back. Try again.", RED)
			return
		end
		if boosts[p] ~= b then
			return
		end
		b.unlocked = true
		C.clearPlayerPrompt(p, "boost:door")
		clearWaypoint(p, "crime_boost")
		local run = newRun("CarBoost", b.spot, { p })
		b.run = run
		C.markDone(p, "CarBoost", "CarBoost")
		PoliceService.raise(p, m.heat, "car boost")
		local body = b.car.PrimaryPart or b.car:FindFirstChildWhichIsA("BasePart", true)
		b.alarm = C.sound(Crime.Sounds.Alarm, body, { looped = true, volume = 0.6, max = 240, speed = 1.4 })
		task.delay(14, function()
			if b.alarm then
				b.alarm:Destroy()
				b.alarm = nil
			end
		end)
		local seat = b.seat :: VehicleSeat?
		if seat then
			seat.Disabled = false
			table.insert(b.conns, seat:GetPropertyChangedSignal("Occupant"):Connect(function()
				local hum = seat.Occupant
				if hum and Players:GetPlayerFromCharacter(hum.Parent) ~= p then
					task.defer(function()
						hum.Sit = false
						hum.Jump = true
					end)
				end
			end))
			local h = C.humanoid(p)
			if h then
				task.delay(0.25, function()
					if seat.Parent and not seat.Occupant then
						seat:Sit(h)
					end
				end)
			end
		end
		local drop = C.point(m.chopShop, "Drop") or CFrame.new(C.siteAt(m.chopShop))
		setWaypoint(p, "crime_chop", drop.Position, "A1 Tires: drop the car", 16)
		objective(p, "Drive it to A1 Tires. Every dent comes off your pay.")
		C.send(p, { type = "runStart", method = "CarBoost", title = "Car boost", pay = m.pay })
		-- damage + delivery watch
		local lastV: Vector3? = nil
		local lastHit = 0
		local unseatedAt = os.clock()
		table.insert(b.conns, RunService.Heartbeat:Connect(function()
			if not seat or not seat.Parent then
				return
			end
			local v = seat.AssemblyLinearVelocity
			if lastV and (lastV - v).Magnitude > m.damageSpeed and os.clock() - lastHit > 0.5 then
				lastHit = os.clock()
				b.hits += 1
				C.send(p, { type = "boostDamage", hits = b.hits, pay = CrimeRules.boostPay(b.hits, m) })
			end
			lastV = v
		end))
		task.spawn(function()
			while boosts[p] == b do
				task.wait(0.25)
				if not seat or not seat.Parent or not b.car.Parent then
					endBoost(p, "lost")
					break
				end
				local h = C.humanoid(p)
				local inSeat = h ~= nil and seat.Occupant == h
				if inSeat then
					unseatedAt = os.clock()
				elseif os.clock() - unseatedAt > 120 then
					Notify.toast(p, "You left the car too long. Smoke says forget it.", RED)
					endBoost(p, "abandoned")
					break
				end
				if inSeat and (seat.Position - drop.Position).Magnitude < 18 then
					local pay = CrimeRules.boostPay(b.hits, m)
					if h then
						h.Sit = false
						h.Jump = true
					end
					C.addDirty(p, pay, "CarBoost", drop.Position)
					giveXP(p, m.xp, "CarBoost", drop.Position)
					stat(p)
					C.Done:Fire(p, "CarBoost", pay)
					Notify.toast(p, string.format("A1 takes it apart. %s (%d dents).", CrimeRules.money(pay), b.hits), GREEN)
					objective(p, "Wash it at the laundromat")
					endBoost(p, "done")
					break
				end
			end
		end)
	end, function()
		if char then
			char:SetAttribute("MTL_Action", nil)
		end
	end)
end

---------------------------------------------------------------- AtmDrill

local atmBusy: { [string]: boolean } = {}

local function drillModel(): Model
	local m = prop("DrillRig")
	if m then
		return m
	end
	m = Instance.new("Model")
	local function part(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, shape: Enum.PartType?)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = mat or Enum.Material.SmoothPlastic
		if shape then
			p.Shape = shape
		end
		p.Anchored = true
		p.CanCollide = false
		p.Parent = m
		return p
	end
	-- a magnetic-base core drill: yellow motor on a grey column, bit into the safe door (-Z)
	local base = part("Base", Vector3.new(1.4, 0.5, 1.0), CFrame.new(0, 0, 0), Color3.fromRGB(70, 70, 76), Enum.Material.Metal)
	part("Column", Vector3.new(0.3, 2.2, 0.3), CFrame.new(0, 1.3, 0.25), Color3.fromRGB(150, 150, 156), Enum.Material.Metal)
	part("Motor", Vector3.new(0.9, 1.0, 1.3), CFrame.new(0, 1.6, -0.25), Color3.fromRGB(240, 186, 40), Enum.Material.SmoothPlastic)
	part("Bit", Vector3.new(0.9, 0.22, 0.22), CFrame.new(0, 1.2, -1.2) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(200, 200, 206), Enum.Material.Metal, Enum.PartType.Cylinder)
	m.PrimaryPart = base
	return m
end

local function startAtm(player: Player, site: string)
	local m = Crime.Methods.AtmDrill
	local mount = C.point(site, "DrillMount") or C.point(site, "Atm")
	if not mount then
		return
	end
	atmBusy[site] = true
	local run = newRun("AtmDrill", site, { player })
	C.markDone(player, "AtmDrill", "AtmDrill:" .. site)
	table.insert(run.cleanup, function()
		task.delay(30, function()
			atmBusy[site] = nil
		end)
	end)
	local rig = drillModel()
	rig.Name = "MTL_DrillRig"
	rig:PivotTo(mount)
	rig.Parent = workspace
	table.insert(run.parts, rig)
	local bit = rig:FindFirstChild("Bit", true) :: BasePart?
	local sparks: ParticleEmitter? = nil
	if bit then
		local a = Instance.new("Attachment")
		a.Position = Vector3.new(0, 0, 0)
		a.Parent = bit
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(255, 210, 120), Color3.fromRGB(255, 120, 40))
		e.LightEmission = 1
		e.Size = NumberSequence.new(0.18, 0)
		e.Lifetime = NumberRange.new(0.2, 0.45)
		e.Speed = NumberRange.new(8, 16)
		e.SpreadAngle = Vector2.new(40, 40)
		e.Acceleration = Vector3.new(0, -40, 0)
		e.Rate = 70
		e.Parent = a
		sparks = e
	end
	local drill = C.sound(Crime.Sounds.Drill, rig.PrimaryPart or mount.Position, { looped = true, volume = 0.9, max = 320 })
	PoliceService.raise(player, m.heat, "ATM drill")
	objective(player, "Hold the block until the drill's through")
	C.send(player, { type = "runStart", method = "AtmDrill", title = "ATM drill", total = m.drillSeconds })
	task.spawn(function()
		local done = 0
		local last = os.clock()
		local stalled = false
		while not run.over do
			task.wait(0.25)
			local now = os.clock()
			local dt = now - last
			last = now
			local r = C.root(player)
			local h = C.humanoid(player)
			if not r or not h or h.Health <= 0 then
				endRun(run, "down")
				break
			end
			local near = (r.Position - mount.Position).Magnitude <= m.leaveRadius
			if near then
				done += dt
			end
			if near == stalled then
				stalled = not near
				if drill then
					drill.PlaybackSpeed = if stalled then 0.6 else 1
				end
				if sparks then
					sparks.Enabled = not stalled
				end
				if stalled then
					Notify.toast(player, "The drill stalls without you. Get back to it.", RED)
				end
			end
			C.send(player, { type = "runProgress", t = math.min(done, m.drillSeconds), total = m.drillSeconds, stalled = stalled })
			if os.clock() - run.started > m.drillSeconds * 3 then
				endRun(run, "timeout")
				break
			end
			if done >= m.drillSeconds then
				if drill then
					drill:Destroy()
					drill = nil
				end
				if sparks then
					sparks.Enabled = false
				end
				C.sound(Crime.Sounds.Break, mount.Position, { volume = 1 })
				PoliceService.raise(player, m.heatDone, "ATM popped")
				objective(player, "Grab the cash")
				local tray = C.point(site, "Tray") or mount * CFrame.new(0, -0.8, -0.6)
				stacksFor(run, tray, CrimeRules.rollStacks(rng, m.stacks, m.stackValue), m.grabSeconds, function()
					giveXP(player, m.xp, "AtmDrill", tray.Position)
					stat(player)
					C.Done:Fire(player, "AtmDrill", 0)
					objective(player, "Get away. Break their line of sight.")
					endRun(run, "done")
				end)
				task.delay(60, function()
					if not run.over then
						endRun(run, "timeout")
					end
				end)
				break
			end
		end
		if drill then
			drill:Destroy()
		end
	end)
	log(player.Name, "ATM drill at", site)
end

---------------------------------------------------------------- Heist (crew)

local heistRun: any = nil

local function crewFor(leader: Player): { Player }
	local m = Crime.Methods.Heist
	local crew = { leader }
	local lr = C.root(leader)
	if not lr then
		return crew
	end
	for _, p in Players:GetPlayers() do
		if p ~= leader and #crew < m.crewMax then
			local r = C.root(p)
			if r and (r.Position - lr.Position).Magnitude <= m.crewRadius and C.canDo(p, "Heist", "Heist:" .. m.site) then
				table.insert(crew, p)
			end
		end
	end
	return crew
end

local function heistFinish(run: any)
	local m = Crime.Methods.Heist
	if run.pot > 0 then
		-- take the pot before paying anyone, so a second call can never pay it twice
		local pot = run.pot
		run.pot = 0
		local shares = CrimeRules.split(pot, #run.players)
		for i, p in run.players do
			if p.Parent then
				C.addDirty(p, shares[i], "Heist")
				giveXP(p, math.floor(m.xp * math.clamp(run.bagsOut / m.bags, 0.3, 1)), "Heist")
				stat(p)
				C.Done:Fire(p, "Heist", shares[i])
				Notify.banner(p, "HEIST DONE", CrimeRules.money(shares[i]) .. " each. Now lose the cops.", GREEN)
				objective(p, "Lose the cops, then wash it")
			end
		end
	end
	for _, p in run.players do
		dropCarry(p)
		clearWaypoint(p, "crime_heist_car")
	end
	heistRun = nil
	endRun(run, "done")
end

local function heistAlarm(run: any)
	if run.alarmOn then
		return
	end
	run.alarmOn = true
	local m = Crime.Methods.Heist
	local box = C.point(m.site, "AlarmBox")
	run.alarm = C.sound(Crime.Sounds.Alarm, if box then box.Position else C.siteAt(m.site), { looped = true, volume = 0.8, max = 320, life = 90 })
	for _, p in run.players do
		PoliceService.raise(p, m.heat, "heist alarm")
	end
end

local function startHeist(leader: Player)
	local m = Crime.Methods.Heist
	local site = m.site
	local entry = C.point(site, "Entry")
	local door = C.point(site, "HeistDoor")
	if not entry or not door then
		refuse(leader, "Not tonight. (The store isn't built yet.)")
		return
	end
	local crew = crewFor(leader)
	local run = newRun("Heist", site, crew)
	heistRun = run
	run.pot = 0
	run.bagsOut = 0
	run.alarmOn = false
	for _, p in crew do
		C.markDone(p, "Heist", "Heist:" .. site)
		C.send(p, { type = "runStart", method = "Heist", title = "Crew heist", crew = #crew, total = m.bags })
		fadeTo(p, entry * CFrame.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-1, 1)))
		objective(p, "Cut the alarm before it trips")
	end
	C.sound(Crime.Sounds.Smash, door.Position, { volume = 1 })
	table.insert(run.cleanup, function()
		if run.alarm then
			task.delay(20, function()
				run.alarm:Destroy()
			end)
		end
		-- the safe closes again for the next crew
		local safeDoor = C.site(site) and (C.site(site) :: Instance):FindFirstChild("SafeDoor", true)
		if safeDoor and safeDoor:IsA("BasePart") and safeDoor:GetAttribute("CF0") then
			task.delay(30, function()
				safeDoor.CFrame = safeDoor:GetAttribute("CF0") :: CFrame
			end)
		end
	end)
	-- 1) the alarm box: 20 s to cut it or it trips
	local box = C.point(site, "AlarmBox")
	if box then
		addPrompt(run, {
			id = run.id .. ":alarm",
			pos = box.Position,
			action = "Cut the alarm",
			object = "Alarm panel",
			hold = m.alarmSeconds,
			range = 6,
			pose = "Pry",
			fn = function(p: Player)
				removePrompt(run, run.id .. ":alarm")
				run.alarmCut = true
				for _, q in run.players do
					Notify.toast(q, p.DisplayName .. " cut the alarm. Quiet now.", GREEN)
					objective(q, "Crack the office safe")
				end
			end,
		})
	end
	task.delay(20, function()
		if not run.over and not run.alarmCut then
			heistAlarm(run)
			for _, q in run.players do
				Notify.toast(q, "The alarm tripped. Move fast.", RED)
				objective(q, "Crack the safe. Fast.")
			end
		end
	end)
	-- 2) the safe
	local safe = C.point(site, "Safe")
	if safe then
		addPrompt(run, {
			id = run.id .. ":safe",
			pos = safe.Position,
			action = "Crack the safe",
			object = "Office safe",
			hold = 0,
			range = 6,
			fn = function(p: Player)
				if run.safeBusy then
					return
				end
				run.safeBusy = true
				local char = p.Character
				if char then
					char:SetAttribute("MTL_Action", "Drill")
				end
				local drill = C.sound(Crime.Sounds.Drill, safe.Position, { looped = true, volume = 0.7, life = 40 })
				C.mini(p, "heist:safe", { kind = "timing", hits = m.safeHits, zone = 0.15, speed = 1.0, verb = "Turn" }, 3, function(q: Player, score: number)
					run.safeBusy = false
					if char then
						char:SetAttribute("MTL_Action", nil)
					end
					if drill then
						drill:Destroy()
					end
					if score < 0.5 then
						Notify.toast(q, "Lost the combination. Go again.", RED)
						return
					end
					removePrompt(run, run.id .. ":safe")
					local safeDoor = C.site(site) and (C.site(site) :: Instance):FindFirstChild("SafeDoor", true)
					if safeDoor and safeDoor:IsA("BasePart") then
						if not safeDoor:GetAttribute("CF0") then
							safeDoor:SetAttribute("CF0", safeDoor.CFrame)
						end
						local hinge = safeDoor.CFrame * CFrame.new(-safeDoor.Size.X / 2, 0, 0)
						local open = hinge * CFrame.Angles(0, math.rad(-100), 0) * CFrame.new(safeDoor.Size.X / 2, 0, 0)
						TweenService:Create(safeDoor, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { CFrame = open }):Play()
					end
					C.sound(Crime.Sounds.Break, safe.Position, { volume = 0.9 })
					-- silent alarm: they always find out, but a cut alarm buys you 25 seconds
					if run.alarmCut then
						task.delay(25, function()
							if not run.over then
								heistAlarm(run)
							end
						end)
					else
						heistAlarm(run)
					end
					for _, z in run.players do
						objective(z, "Carry the bags out to the car")
					end
					-- the bags
					local bagAt = C.point(site, "Bags") or safe * CFrame.new(0, 0, -2.5)
					for i = 1, m.bags do
						local value = CrimeRules.roll(rng, m.bagValue)
						local bag = C.buildDuffel(1)
						anchorAll(bag)
						bag:PivotTo(bagAt * CFrame.new((i - (m.bags + 1) / 2) * 1.4, 0.55, 0) * CFrame.Angles(0, math.rad(90), 0))
						bag.Parent = workspace
						table.insert(run.parts, bag)
						local id = run.id .. ":bag" .. i
						addPrompt(run, {
							id = id,
							pos = bag:GetPivot().Position,
							action = "Take bag",
							object = CrimeRules.money(value),
							hold = 0.5,
							range = 7,
							fn = function(z: Player)
								if carrying[z] then
									Notify.toast(z, "One bag at a time.")
									return
								end
								if not bag.Parent then
									return
								end
								removePrompt(run, id)
								bag.Parent = nil
								setCarry(z, "Bag", value, bag, "Side")
							end,
						})
					end
				end, function()
					run.safeBusy = false
					if char then
						char:SetAttribute("MTL_Action", nil)
					end
					if drill then
						drill:Destroy()
					end
				end)
			end,
		})
	end
	-- 3) out the back door to the crew car
	local exit = C.point(site, "Exit") or entry
	addPrompt(run, {
		id = run.id .. ":out",
		pos = exit.Position,
		action = "Go outside",
		object = "Back door",
		hold = 0,
		range = 7,
		fn = function(p: Player)
			fadeTo(p, door * CFrame.new(0, 0, -4))
		end,
	})
	addPrompt(run, {
		id = run.id .. ":in",
		pos = door.Position,
		action = "Go inside",
		object = "Back door",
		hold = 0,
		range = 7,
		fn = function(p: Player)
			fadeTo(p, entry)
		end,
	})
	local carAt = C.point(site, "Car")
	if carAt then
		local actors = ReplicatedStorage:FindFirstChild("MTL_Actors")
		local t = actors and actors:FindFirstChild("CrewCar")
		local car = if t and t:IsA("Model") then t:Clone() else vanModel()
		car.Name = "MTL_HeistCar"
		for _, d in car:GetDescendants() do
			if d:IsA("BaseScript") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		car:PivotTo(carAt)
		car.Parent = workspace
		table.insert(run.parts, car)
		local trunk = carAt * CFrame.new(0, 0, 8)
		for _, p in crew do
			setWaypoint(p, "crime_heist_car", trunk.Position, "Crew car", 8)
		end
		addPrompt(run, {
			id = run.id .. ":load",
			pos = trunk.Position + Vector3.new(0, 2, 0),
			action = "Load bag",
			object = "Crew car",
			hold = 0.3,
			range = 9,
			fn = function(p: Player)
				local kind, value = dropCarry(p)
				if not kind then
					if run.bagsOut > 0 then
						heistFinish(run)
					end
					return
				end
				run.pot += value
				run.bagsOut += 1
				for _, q in run.players do
					C.send(q, { type = "runProgress", count = run.bagsOut, total = m.bags, value = run.pot })
				end
				if run.bagsOut >= m.bags then
					heistFinish(run)
				end
			end,
		})
	end
	-- 6 minutes max inside
	task.delay(360, function()
		if not run.over then
			heistFinish(run)
		end
	end)
	log(leader.Name, "heist with", #crew)
end

---------------------------------------------------------------- start prompts at the sites

local function sitePrompts()
	-- House licks: the back door of each rental
	for _, site in Crime.Methods.HouseLick.sites do
		local back = C.point(site, "BackDoor")
		if back then
			C.addGlobalPrompt({
				id = "lick:" .. site,
				pos = back.Position,
				action = "Pry the back door",
				object = "Rental on NW 52nd",
				hold = 2.5,
				range = 7,
				pose = "Pry",
				visible = function(p: Player)
					return C.isCriminal(p) and not houseBusy[site] and not C.runs[p]
				end,
				fn = function(p: Player)
					if houseBusy[site] then
						return
					end
					local ok, why = C.canDo(p, "HouseLick", "HouseLick:" .. site)
					if not ok then
						refuse(p, why or "Not now")
						return
					end
					startLick(p, site)
				end,
			})
		end
	end
	-- ATMs
	for _, site in Crime.Methods.AtmDrill.sites do
		local atm = C.point(site, "Atm")
		if atm then
			C.addGlobalPrompt({
				id = "atm:" .. site,
				pos = atm.Position,
				action = "Bolt on the drill",
				object = "ATM",
				hold = Crime.Methods.AtmDrill.attachSeconds,
				range = 6,
				pose = "Drill",
				visible = function(p: Player)
					return C.isCriminal(p) and not atmBusy[site] and not C.runs[p]
				end,
				fn = function(p: Player)
					if atmBusy[site] then
						return
					end
					local ok, why = C.canDo(p, "AtmDrill", "AtmDrill:" .. site)
					if not ok then
						refuse(p, why or "Not now")
						return
					end
					startAtm(p, site)
				end,
			})
		end
	end
	-- The heist door
	local hm = Crime.Methods.Heist
	local door = C.point(hm.site, "HeistDoor")
	if door then
		C.addGlobalPrompt({
			id = "heist",
			pos = door.Position,
			action = "Pry the door (crew heist)",
			object = "Cash 4 Gold, after close",
			hold = 3,
			range = 7,
			pose = "Pry",
			visible = function(p: Player)
				return C.isCriminal(p) and heistRun == nil and not C.runs[p]
			end,
			fn = function(p: Player)
				if heistRun then
					return
				end
				local ok, why = C.canDo(p, "Heist", "Heist:" .. hm.site)
				if not ok then
					refuse(p, why or "Not now")
					return
				end
				startHeist(p)
			end,
		})
	end
end

---------------------------------------------------------------- the offer loop (tips + boosts arrive by text)

local nextOffer: { [Player]: number } = {}

local function offerTick()
	local now = os.clock()
	for _, p in Players:GetPlayers() do
		if not C.isCriminal(p) then
			continue
		end
		local t = tips[p]
		if t and now > t.expires then
			tips[p] = nil
			C.clearPlayerPrompt(p, "tip:" .. t.spot)
			clearWaypoint(p, "crime_tip")
		end
		local b = boosts[p]
		if b and not b.unlocked and now > b.expires then
			endBoost(p, "expired")
		end
		if C.runs[p] or now < (nextOffer[p] or 0) then
			continue
		end
		nextOffer[p] = now + rng:NextNumber(60, 120)
		local wantTip = not tips[p] and C.canDo(p, "TipJob", "TipJob")
		local wantBoost = not boosts[p] and C.canDo(p, "CarBoost", "CarBoost")
		if wantTip and (not wantBoost or rng:NextNumber() < 0.5) then
			sendTip(p)
		elseif wantBoost then
			offerBoost(p)
		end
	end
	-- walls come back
	for spot, at in wallsDown do
		if now > at then
			wallsDown[spot] = nil
			setWall(spot, true)
		end
	end
end

---------------------------------------------------------------- public

function CrimeJobs.abort(player: Player, reason: string)
	dropCarry(player)
	local run = C.runs[player]
	if run then
		if #run.players <= 1 then
			if run.method == "HouseLick" then
				finishLick(run, false)
			else
				endRun(run, reason)
			end
		else
			local i = table.find(run.players, player)
			if i then
				table.remove(run.players, i)
			end
			C.runs[player] = nil
			if run.leader == player then
				run.leader = run.players[1]
			end
		end
	end
	if boosts[player] then
		endBoost(player, reason)
	end
	if reason == "left" then
		tips[player] = nil
		nextOffer[player] = nil
	end
end

function CrimeJobs.resync(player: Player)
	local t = tips[player]
	if t then
		tipPrompt(player, t.spot)
	end
end

-- Studio: force a tip / boost offer right now.
function CrimeJobs.debugOffer(player: Player, which: string)
	if which == "tip" then
		sendTip(player)
	elseif which == "boost" then
		offerBoost(player)
	end
end

function CrimeJobs.init(crimeService: any)
	C = crimeService
	task.defer(function()
		spawnClerks()
		sitePrompts()
	end)
	local guns = sibling("GunService")
	if guns and guns.Intimidating then
		guns.Intimidating:Connect(onIntimidating)
	else
		warn("[MTL Crime] GunService.Intimidating missing: stickups can't start")
	end
	if guns and guns.Fired then
		guns.Fired:Connect(function(player: Player)
			local run = inRun(player, "Stickup")
			if run then
				PoliceService.raise(player, Crime.Methods.Stickup.heatIfShots, "shots in a stickup")
			end
		end)
	end
	-- death drops whatever you carry
	local function watch(p: Player)
		p.CharacterAdded:Connect(function(char)
			local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
			if hum then
				hum.Died:Connect(function()
					dropCarry(p)
					local run = C.runs[p]
					if run and #run.players <= 1 and run.method ~= "HouseLick" and run.method ~= "Heist" then
						endRun(run, "down")
					elseif run and run.method == "HouseLick" then
						finishLick(run, false)
					end
					if boosts[p] and boosts[p].unlocked then
						endBoost(p, "down")
					end
				end)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	task.spawn(function()
		while true do
			task.wait(5)
			local ok, err = pcall(offerTick)
			if not ok then
				warn("[MTL Crime] offer tick failed:", err)
			end
		end
	end)
end

return CrimeJobs
