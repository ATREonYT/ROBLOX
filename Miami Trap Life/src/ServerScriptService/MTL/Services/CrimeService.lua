--!strict
-- The crime loop's core (Config/Crime, research §5 P0-1 and P0-3):
--   * dirty cash: data.Crime.Dirty, carried in a duffel on your back. Going down drops half as a pickup anyone can
--     grab; getting cuffed loses it. Washed clean at Liberty Laundromat's back counter (time + a cut).
--   * Marcus at the Cash 4 Gold back door: sells the crime tools (clean cash) and fences house-lick goods.
--   * the per-player prompt list (the client makes local ProximityPrompts from it; the server checks every press),
--     the minigame handshake, cooldowns (data.Crime.Last + data.Earn.Ready for the phone's Money app), unlock texts.
--   * the six crimes live in CrimeJobs.lua (required from here, initialised with this module as its context).
--
-- Remotes: CrimeState (S->C) {type=...}, CrimeAction (C->S) {type="holdBegin"|"prompt"|"mini"|"buyTool"|"fence"|
--   "washCancel"|"shopClose", ...}. Player attributes: MTL_Dirty (bag size for every client), MTL_Heat (PoliceService).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Crime = require(ReplicatedStorage.MTL.Config.Crime)
local CrimeRules = require(ReplicatedStorage.MTL.Rules.CrimeRules)
local StoryRules = require(ReplicatedStorage.MTL.Rules.StoryRules)
local Net = require(ReplicatedStorage.MTL.Net)
local Signal = require(ReplicatedStorage.MTL.Signal)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local Notify = require(script.Parent.Notify)

-- House rule (HUD thread): every refused action tells the player why, through Notify.refuse when it exists.
local function refuse(player: Player, text: string)
	local n = Notify :: any
	if n.refuse then
		n.refuse(player, text)
	else
		Notify.toast(player, text, Color3.fromRGB(226, 72, 72))
	end
end
local RateLimiter = require(script.Parent.RateLimiter)
local PoliceService = require(script.Parent.PoliceService)

local CrimeService = {}
CrimeService.DirtyChanged = Signal.new() -- (player, dirty, delta, reason)
CrimeService.Done = Signal.new() -- (player, methodId, take)

local D = Crime.Dirty
local W = Crime.Wash

local limiter = RateLimiter.new(14, 6)
local rng = Random.new()

local function log(...)
	print("[MTL Crime]", ...)
end

local function send(player: Player, payload: any)
	Net.get("CrimeState"):FireClient(player, payload)
end
CrimeService.send = send

local function root(player: Player): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end
CrimeService.root = root

local function humanoid(player: Player): Humanoid?
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end
CrimeService.humanoid = humanoid

local function sibling(name: string): any?
	local m = script.Parent:FindFirstChild(name)
	if not m then
		return nil
	end
	local ok, svc = pcall(require, m)
	return if ok then svc else nil
end
CrimeService.sibling = sibling

---------------------------------------------------------------- save data

-- data.Crime = { Dirty, Fence (goods waiting for Marcus, $), Last[key] = os.time, Count[method] = n, Told[method] = true }
local FenceMax = 20000 -- more goods than 4 full house licks can ever be waiting
function CrimeService.data(player: Player): any?
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local c = data.Crime
	if type(c) ~= "table" then
		c = { Dirty = 0, Fence = 0, Last = {}, Count = {}, Told = {} }
		data.Crime = c
	end
	-- validated on every read: finite, whole, non-negative, under the cap (a NaN/inf/negative/huge value is reset and
	-- flagged once per session for review instead of being trusted)
	local function sane(v: any, cap: number, field: string): number
		if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge or v < 0 then
			if v ~= nil and v ~= 0 and not player:GetAttribute("MTL_EconFlag") then
				player:SetAttribute("MTL_EconFlag", "Crime." .. field .. "=" .. tostring(v))
				warn("[MTL Crime] bad", field, "for", player.Name, v)
			end
			return 0
		end
		if v > cap then
			if not player:GetAttribute("MTL_EconFlag") then
				player:SetAttribute("MTL_EconFlag", "Crime." .. field .. " over cap: " .. tostring(v))
				warn("[MTL Crime] over cap", field, "for", player.Name, v)
			end
			return cap
		end
		return math.floor(v)
	end
	c.Dirty = sane(c.Dirty, D.Max, "Dirty")
	c.Fence = sane(c.Fence, FenceMax, "Fence")
	c.Last = if type(c.Last) == "table" then c.Last else {}
	c.Count = if type(c.Count) == "table" then c.Count else {}
	c.Told = if type(c.Told) == "table" then c.Told else {}
	return c
end

function CrimeService.dirty(player: Player): number
	local c = CrimeService.data(player)
	return if c then c.Dirty else 0
end

local refreshBag: (Player) -> () -- defined below

local function setDirty(player: Player, value: number, reason: string)
	local c = CrimeService.data(player)
	if not c then
		return
	end
	local old = c.Dirty
	c.Dirty = math.clamp(math.floor(value), 0, D.Max)
	player:SetAttribute("MTL_Dirty", c.Dirty)
	if c.Dirty ~= old then
		CrimeService.DirtyChanged:Fire(player, c.Dirty, c.Dirty - old, reason)
		send(player, { type = "dirty", dirty = c.Dirty, delta = c.Dirty - old, reason = reason })
		refreshBag(player)
		DataService.push(player)
		local analytics = game:GetService("AnalyticsService")
		pcall(function()
			local flow = if c.Dirty > old then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink
			local data = DataService.get(player)
			local lvl = if data then data.Level or 1 else 1
			local band = "lvl_" .. (lvl // 10) * 10 .. "_" .. (lvl // 10) * 10 + 9
			analytics:LogEconomyEvent(player, flow, "Dirty", math.abs(c.Dirty - old), c.Dirty, Enum.AnalyticsEconomyTransactionType.Gameplay.Name, reason, {
				[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = band,
				[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = Crime.EconVersion or "econ_v1",
			})
		end)
	end
end

-- Adds dirty cash (capped). Returns what was actually added. `at` = where the "+$120" pops.
function CrimeService.addDirty(player: Player, amount: number, reason: string, at: Vector3?): number
	local c = CrimeService.data(player)
	if not c then
		return 0
	end
	local new, added = CrimeRules.addDirty(c.Dirty, amount, D.Max)
	if added > 0 then
		setDirty(player, new, reason)
		send(player, { type = "pop", amount = added, at = at })
	elseif amount > 0 then
		refuse(player, "Your bag is full. Wash some at the laundromat.")
	end
	return added
end

---------------------------------------------------------------- rules: who can do what

local function storyStage(data: any): string
	return if data and data.Story and type(data.Story.Stage) == "string" then data.Story.Stage else StoryRules.first()
end

function CrimeService.isCriminal(player: Player): boolean
	local data = DataService.get(player)
	return data ~= nil and data.Path == Crime.Requires.Path and StoryRules.reached(storyStage(data), Crime.Requires.Stage)
end

function CrimeService.hasTool(player: Player, tool: string): boolean
	local data = DataService.get(player)
	return data ~= nil and data.Inventory and data.Inventory.Items and data.Inventory.Items[tool] == true
end

local function hasAnyGun(player: Player): boolean
	local data = DataService.get(player)
	if not data or not data.Inventory or not data.Inventory.Guns then
		return false
	end
	return next(data.Inventory.Guns) ~= nil
end

local runs: { [Player]: any } = {} -- the run each player is part of (CrimeJobs)
CrimeService.runs = runs

-- Can `player` start `methodId` (at `key` = the cooldown key, usually method..":"..site)? -> ok, reason
function CrimeService.canDo(player: Player, methodId: string, key: string?): (boolean, string?)
	local m = Crime.method(methodId)
	local data = DataService.get(player)
	if not m or not data then
		return false, "Not now"
	end
	if data.Path ~= Crime.Requires.Path then
		return false, "Criminal life only (Settings > Lifestyle)"
	end
	if not StoryRules.reached(storyStage(data), Crime.Requires.Stage) then
		return false, "Finish your first job with the crew first"
	end
	if (data.Level or 1) < m.level then
		return false, "Level " .. m.level .. " for " .. string.lower(m.title)
	end
	local tools = m.tools or (if m.tool then { m.tool } else {})
	for _, t in tools do
		if not CrimeService.hasTool(player, t) then
			return false, "You need " .. string.lower(Crime.Tools[t].title) .. " (Marcus, Cash 4 Gold back door)"
		end
	end
	if m.needsGun and not hasAnyGun(player) then
		return false, "You need a gun for this"
	end
	local jobs = sibling("JobService")
	if jobs and jobs.isOnShift then
		local ok, on = pcall(jobs.isOnShift, player)
		if ok and on then
			return false, "Clock out first"
		end
	end
	if runs[player] then
		return false, "Finish what you're doing first"
	end
	local c = CrimeService.data(player)
	local k = key or methodId
	if c and not CrimeRules.isReady(c.Last[k], m.cooldown, os.time()) then
		return false, "Hot spot. Ready in " .. CrimeRules.clock(CrimeRules.readyAt(c.Last[k], m.cooldown) - os.time())
	end
	return true, nil
end

-- The cooldown starts now for `key`; also refreshes data.Earn.Ready for the phone's Money app.
local publishReady: (Player) -> ()
function CrimeService.markDone(player: Player, methodId: string, key: string?)
	local c = CrimeService.data(player)
	if not c then
		return
	end
	c.Last[key or methodId] = os.time()
	c.Count[methodId] = (c.Count[methodId] or 0) + 1
	publishReady(player)
	DataService.push(player)
end

-- data.Earn.Ready[id] = os.time() the method is next ready anywhere (phone thread's Config/Earn contract).
function publishReady(player: Player)
	local data = DataService.get(player)
	local c = CrimeService.data(player)
	if not data or not c then
		return
	end
	if type(data.Earn) ~= "table" then
		data.Earn = { Ready = {} }
	end
	if type(data.Earn.Ready) ~= "table" then
		data.Earn.Ready = {}
	end
	for _, id in Crime.MethodOrder do
		local m = Crime.method(id)
		local keys = {}
		for _, s in (m.sites or m.spots or { m.site or id }) do
			table.insert(keys, if m.sites or m.site then id .. ":" .. s else id)
		end
		data.Earn.Ready[id] = CrimeRules.soonest(c.Last, keys, m.cooldown)
	end
end
CrimeService.publishReady = publishReady

---------------------------------------------------------------- places

-- Workspace.MTL_CrimeSites.<siteId>.<point> (an invisible part) -> CFrame. Falls back to Crime.Sites[siteId].at.
function CrimeService.point(siteId: string, name: string): CFrame?
	local sites = workspace:FindFirstChild("MTL_CrimeSites")
	local site = sites and sites:FindFirstChild(siteId)
	local p = site and site:FindFirstChild(name, true)
	if p and p:IsA("BasePart") then
		return p.CFrame
	end
	return nil
end

function CrimeService.site(siteId: string): Instance?
	local sites = workspace:FindFirstChild("MTL_CrimeSites")
	return sites and sites:FindFirstChild(siteId)
end

function CrimeService.siteAt(siteId: string): Vector3
	local s = (Crime.Sites :: any)[siteId]
	local cf = CrimeService.point(siteId, "Center")
	return if cf then cf.Position elseif s then s.at else Vector3.zero
end

-- A sound at a part or a position. Returns the Sound (looped ones: stop/destroy it yourself).
function CrimeService.sound(id: string, at: BasePart | Vector3, opts: { [string]: any }?): Sound?
	if id == "" then
		return nil
	end
	local o = opts or {}
	local host: Instance
	if typeof(at) == "Vector3" then
		local a = Instance.new("Attachment")
		a.WorldPosition = at
		a.Parent = workspace.Terrain
		host = a
		task.delay(o.life or (if o.looped then 120 else 8), function()
			a:Destroy()
		end)
	else
		host = at
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = o.volume or 0.8
	s.Looped = o.looped == true
	s.PlaybackSpeed = o.speed or 1
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = o.min or 12
	s.RollOffMaxDistance = o.max or 220
	s.Parent = host
	s:Play()
	if not s.Looped then
		task.delay(o.life or 8, function()
			if s.Parent then
				s:Destroy()
			end
		end)
	end
	return s
end

---------------------------------------------------------------- the duffel on your back

-- ReplicatedStorage.MTL_Actors.CashBag (the quality thread's duffel, pivot at its centre) when it's there.
local function bagTemplate(): Model?
	local actors = ReplicatedStorage:FindFirstChild("MTL_Actors")
	local t = actors and actors:FindFirstChild("CashBag")
	return if t and t:IsA("Model") then t else nil
end

-- A duffel: black nylon body, end caps, straps, a strip of bills peeking out of the zip.
function CrimeService.buildDuffel(scale: number): Model
	local t = bagTemplate()
	local m: Model
	if t then
		m = t:Clone()
		if scale ~= 1 then
			pcall(function()
				m:ScaleTo(scale)
			end)
		end
	else
		m = Instance.new("Model")
		local function part(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, shape: Enum.PartType?): Part
			local p = Instance.new("Part")
			p.Name = name
			p.Size = size * scale
			p.CFrame = CFrame.new(cf.Position * scale) * cf.Rotation
			p.Color = color
			p.Material = mat
			if shape then
				p.Shape = shape
			end
			p.Parent = m
			return p
		end
		local black = Color3.fromRGB(22, 22, 26)
		local body = part("Body", Vector3.new(2.1, 1.05, 1.05), CFrame.new(), black, Enum.Material.Fabric, Enum.PartType.Cylinder)
		part("CapL", Vector3.new(0.08, 1.1, 1.1), CFrame.new(-1.06, 0, 0), Color3.fromRGB(40, 40, 46), Enum.Material.Fabric, Enum.PartType.Cylinder)
		part("CapR", Vector3.new(0.08, 1.1, 1.1), CFrame.new(1.06, 0, 0), Color3.fromRGB(40, 40, 46), Enum.Material.Fabric, Enum.PartType.Cylinder)
		part("Zip", Vector3.new(1.9, 0.08, 0.14), CFrame.new(0, 0.52, 0), Color3.fromRGB(120, 120, 126), Enum.Material.Metal)
		part("Bills", Vector3.new(0.9, 0.16, 0.42), CFrame.new(0.2, 0.5, 0.05) * CFrame.Angles(0, 0, math.rad(4)), Color3.fromRGB(110, 168, 96), Enum.Material.SmoothPlastic)
		part("Band", Vector3.new(0.18, 0.18, 0.44), CFrame.new(0.2, 0.52, 0.05), Color3.fromRGB(226, 196, 120), Enum.Material.SmoothPlastic)
		part("StrapA", Vector3.new(0.14, 0.6, 1.12), CFrame.new(-0.55, 0.05, 0), Color3.fromRGB(14, 14, 16), Enum.Material.Fabric)
		part("StrapB", Vector3.new(0.14, 0.6, 1.12), CFrame.new(0.55, 0.05, 0), Color3.fromRGB(14, 14, 16), Enum.Material.Fabric)
		m.PrimaryPart = body
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BaseScript") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		end
	end
	return m
end

function refreshBag(player: Player)
	local char = player.Character
	local torso = char and (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")) :: BasePart?
	if not char or not torso then
		return
	end
	local dirty = CrimeService.dirty(player)
	local want = if dirty >= D.BagShowAt then (if dirty >= D.BagBigAt then "Big" else "Small") else ""
	local old = char:FindFirstChild("MTL_DirtyBag")
	if old and old:GetAttribute("Size") == want then
		return
	end
	if old then
		old:Destroy()
	end
	if want == "" then
		return
	end
	local m = CrimeService.buildDuffel(if want == "Big" then 1.0 else 0.8)
	m.Name = "MTL_DirtyBag"
	m:SetAttribute("Size", want)
	local body = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart") :: BasePart
	-- across the back, slung low and a touch tilted
	local size = m:GetExtentsSize()
	m:PivotTo(torso.CFrame * CFrame.new(0, -0.15, torso.Size.Z / 2 + size.Z / 2 - 0.05) * CFrame.Angles(0, 0, math.rad(-18)))
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			local w = Instance.new("WeldConstraint")
			w.Part0 = torso
			w.Part1 = d
			w.Parent = d
		end
	end
	local _ = body
	m.Parent = char
end
CrimeService.refreshBag = refreshBag

---------------------------------------------------------------- dropped bags

type Pickup = { model: Model, part: BasePart, amount: number, owner: Player?, ownerAt: number, expires: number, first: Player?, firstUntil: number? }
local pickups: { Pickup } = {}

local function updatePickupLabel(p: Pickup)
	local bb = p.part:FindFirstChild("Label") :: BillboardGui?
	local text = bb and bb:FindFirstChild("Amount", true) :: TextLabel?
	if text then
		text.Text = CrimeRules.money(p.amount)
	end
end

local function dropPickup(at: Vector3, amount: number, owner: Player?)
	local m = CrimeService.buildDuffel(0.9)
	m.Name = "MTL_DroppedCash"
	local body = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart") :: BasePart
	m.PrimaryPart = body
	-- on the floor where you went down (raycast so it doesn't float or sink)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { m }
	for _, pl in Players:GetPlayers() do
		if pl.Character then
			table.insert(ignore, pl.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(at + Vector3.new(0, 3, 0), Vector3.new(0, -20, 0), params)
	local y = if hit then hit.Position.Y else at.Y - 2.5
	m:PivotTo(CFrame.new(at.X, y + body.Size.Y / 2 + 0.02, at.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "Label"
	bb.Size = UDim2.fromOffset(120, 34)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 90
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(24, 25, 29)
	bg.BackgroundTransparency = 0.15
	bg.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = bg
	local t = Instance.new("TextLabel")
	t.Name = "Amount"
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(92, 196, 104)
	t.Parent = bg
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 5)
	pad.PaddingBottom = UDim.new(0, 5)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = bg
	bb.Parent = body
	-- a soft green glow so it reads at night
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(92, 196, 104)
	light.Range = 7
	light.Brightness = 1.2
	light.Parent = body
	CollectionService:AddTag(m, "MTL_DroppedCash")
	m.Parent = workspace
	local p: Pickup = {
		model = m,
		part = body,
		amount = amount,
		owner = owner,
		ownerAt = os.clock() + D.PickupOwnerDelay,
		expires = os.clock() + D.PickupLife,
	}
	updatePickupLabel(p)
	table.insert(pickups, p)
	log("dropped", amount, "at", math.floor(at.X), math.floor(at.Z))
end

local function pickupTick()
	local now = os.clock()
	for i = #pickups, 1, -1 do
		local p = pickups[i]
		if now > p.expires or not p.model.Parent then
			p.model:Destroy()
			table.remove(pickups, i)
			continue
		end
		for _, pl in Players:GetPlayers() do
			local r = root(pl)
			local h = humanoid(pl)
			if r and h and h.Health > 0 and (r.Position - p.part.Position).Magnitude <= D.PickupRadius then
				if pl == p.owner and now < p.ownerAt then
					continue
				end
				-- the player who finished them gets a head start on the bag
				if p.first and pl ~= p.first and p.first.Parent and now < (p.firstUntil or 0) then
					continue
				end
				local took = CrimeService.addDirty(pl, p.amount, "Pickup", p.part.Position)
				if took > 0 then
					CrimeService.sound(Crime.Sounds.CashGrab, p.part.Position, { volume = 0.7 })
					p.amount -= took
					if p.amount <= 0 then
						p.model:Destroy()
						table.remove(pickups, i)
						break
					end
					updatePickupLabel(p)
				end
			end
		end
	end
end

---------------------------------------------------------------- prompts (per player, client-made)

-- entry = { id, pos, action, object, hold, range, fn(player, entry), key?, style? }
type Entry = { [string]: any }
local globalPrompts: { [string]: Entry } = {}
local holdBegan: { [Player]: { [string]: number } } = {}
local sentAt: { [Player]: number } = {}
local dirtyPrompts: { [Player]: boolean } = {}

-- `visible(player, entry)` (optional) filters global prompts per player.
function CrimeService.addGlobalPrompt(e: Entry)
	globalPrompts[e.id] = e
	for _, p in Players:GetPlayers() do
		dirtyPrompts[p] = true
	end
end

function CrimeService.removeGlobalPrompt(id: string)
	globalPrompts[id] = nil
	for _, p in Players:GetPlayers() do
		dirtyPrompts[p] = true
	end
end

-- Prompts for one player outside a run (a tip spot only they were told about, their boost car's door).
local extraPrompts: { [Player]: { [string]: Entry } } = {}
function CrimeService.setPlayerPrompt(player: Player, e: Entry)
	extraPrompts[player] = extraPrompts[player] or {}
	extraPrompts[player][e.id] = e
	dirtyPrompts[player] = true
end

function CrimeService.clearPlayerPrompt(player: Player, id: string)
	local t = extraPrompts[player]
	if t and t[id] then
		t[id] = nil
		dirtyPrompts[player] = true
	end
end

local function promptsFor(player: Player): { [string]: Entry }
	local out: { [string]: Entry } = {}
	for id, e in globalPrompts do
		if not e.visible or e.visible(player, e) then
			out[id] = e
		end
	end
	local extra = extraPrompts[player]
	if extra then
		for id, e in extra do
			out[id] = e
		end
	end
	local run = runs[player]
	if run and run.prompts then
		for id, e in run.prompts do
			if not e.only or e.only == player then
				out[id] = e
			end
		end
	end
	return out
end

local function sendPrompts(player: Player)
	local list = {}
	for id, e in promptsFor(player) do
		table.insert(list, {
			id = id,
			pos = e.pos,
			action = e.action,
			object = e.object or "",
			hold = e.hold or 0,
			range = e.range or 8,
			key = e.key,
			style = e.style,
			pose = e.pose, -- ActionPose loop the client plays on you while you hold (Pry, Drill, ...)
		})
	end
	send(player, { type = "prompts", list = list })
	sentAt[player] = os.clock()
end

-- Re-send prompt lists soon (batched to one send per player per frame).
function CrimeService.touchPrompts(players: { Player }?)
	for _, p in (players or Players:GetPlayers()) do
		dirtyPrompts[p] = true
	end
end

local function onPrompt(player: Player, id: string)
	local e = promptsFor(player)[id]
	local r = root(player)
	local h = humanoid(player)
	if not e or not r or not h or h.Health <= 0 then
		return
	end
	if player.Character and player.Character:GetAttribute("MTL_Downed") then
		return -- downed players crawl; no prompts
	end
	local pos: Vector3 = e.pos
	if (r.Position - pos).Magnitude > (e.range or 8) + 6 then
		return
	end
	local hold = e.hold or 0
	if hold > 0 then
		local began = holdBegan[player] and holdBegan[player][id]
		if not began or os.clock() - began < hold * 0.7 then
			return
		end
		holdBegan[player][id] = nil
	end
	local ok, err = pcall(e.fn, player, e)
	if not ok then
		warn("[MTL Crime] prompt", id, "failed:", err)
	end
end

---------------------------------------------------------------- minigames (JobMinigames on the client)

type Mini = { id: string, started: number, min: number, fn: (Player, number) -> (), cancel: ((Player) -> ())? }
local minis: { [Player]: Mini } = {}

-- Starts a minigame on the client: info = JobMinigames info {kind="timing"|"hold"|"sequence", hits, zone, speed, verb,
-- seconds}. fn(player, score 0-1) runs when it ends (not faster than `min` seconds after it started).
function CrimeService.mini(player: Player, id: string, info: any, min: number, fn: (Player, number) -> (), cancel: ((Player) -> ())?)
	minis[player] = { id = id, started = os.clock(), min = min, fn = fn, cancel = cancel }
	send(player, { type = "mini", id = id, info = info })
end

function CrimeService.cancelMini(player: Player)
	if minis[player] then
		minis[player] = nil
		send(player, { type = "miniCancel" })
	end
end

local function onMini(player: Player, msg: any)
	local m = minis[player]
	if not m or msg.id ~= m.id then
		return
	end
	minis[player] = nil
	if msg.cancel == true then
		if m.cancel then
			pcall(m.cancel, player)
		end
		return
	end
	local score = if type(msg.score) == "number" and msg.score == msg.score then math.clamp(msg.score, 0, 1) else 0
	if os.clock() - m.started < m.min then
		score = 0 -- too fast to be real
	end
	local ok, err = pcall(m.fn, player, score)
	if not ok then
		warn("[MTL Crime] minigame", m.id, "failed:", err)
	end
end

---------------------------------------------------------------- cash stacks (shared by stickups, tip jobs, ATMs)

-- A banded stack of bills (anchored, no collisions). Returns the model.
function CrimeService.buildStack(cf: CFrame, value: number): Model
	-- the quality thread's banded-bills mesh (1.25 x 0.3 x 0.9), scaled down for small stacks
	local actors = ReplicatedStorage:FindFirstChild("MTL_Actors")
	local mesh = actors and actors:FindFirstChild("CashStack")
	if mesh and mesh:IsA("BasePart") then
		local m = Instance.new("Model")
		m.Name = "MTL_CashStack"
		local p = mesh:Clone()
		local k = if value >= 150 then 0.62 else 0.52
		p.Size = mesh.Size * k
		p.CFrame = cf * CFrame.new(0, p.Size.Y / 2, 0)
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Parent = m
		m.PrimaryPart = p
		return m
	end
	local m = Instance.new("Model")
	m.Name = "MTL_CashStack"
	local green = Color3.fromRGB(116, 170, 100)
	local function part(name: string, size: Vector3, off: CFrame, color: Color3, mat: Enum.Material)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf * off
		p.Color = color
		p.Material = mat
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Parent = m
		return p
	end
	local h = if value >= 150 then 0.34 else 0.24
	local base = part("Bills", Vector3.new(0.62, h, 0.28), CFrame.new(0, h / 2, 0), green, Enum.Material.SmoothPlastic)
	part("Top", Vector3.new(0.6, 0.02, 0.26), CFrame.new(0, h + 0.01, 0), Color3.fromRGB(150, 196, 132), Enum.Material.SmoothPlastic)
	part("Band", Vector3.new(0.14, h + 0.03, 0.3), CFrame.new(0, h / 2, 0), Color3.fromRGB(226, 196, 120), Enum.Material.SmoothPlastic)
	m.PrimaryPart = base
	return m
end

-- Lays out `values` as stacks on a surface CFrame (rows of 3, spaced) and returns { {model, value, cf} }.
function CrimeService.layStacks(parent: Instance, surface: CFrame, values: { number }, spacing: Vector3?): { any }
	local sp = spacing or Vector3.new(0.8, 0, 0.45)
	local out = {}
	local perRow = 3
	local rows = math.ceil(#values / perRow)
	for i, v in values do
		local col = (i - 1) % perRow
		local row = (i - 1) // perRow
		local x = (col - (math.min(perRow, #values) - 1) / 2) * sp.X
		local z = (row - (rows - 1) / 2) * sp.Z
		local cf = surface * CFrame.new(x, 0, z) * CFrame.Angles(0, rng:NextNumber(-0.25, 0.25), 0)
		local m = CrimeService.buildStack(cf, v)
		m.Parent = parent
		table.insert(out, { model = m, value = v, cf = cf })
	end
	return out
end

---------------------------------------------------------------- washing (Liberty Laundromat back counter)

type Wash = { amount: number, cut: number, seconds: number, started: number, at: Vector3, sound: Sound? }
local washing: { [Player]: Wash } = {}

local function endWash(player: Player, ok: boolean, why: string?)
	local w = washing[player]
	if not w then
		return
	end
	washing[player] = nil
	if w.sound then
		w.sound:Destroy()
	end
	local char = player.Character
	if char then
		char:SetAttribute("MTL_Action", nil)
	end
	if ok then
		local c = CrimeService.data(player)
		local amount = math.min(w.amount, if c then c.Dirty else 0)
		local clean, cut = CrimeRules.washPayout(amount, w.cut)
		setDirty(player, (if c then c.Dirty else 0) - amount, "Wash")
		EconomyService.addCash(player, clean, "Wash", false, w.at)
		send(player, { type = "washEnd", ok = true, clean = clean, cut = cut })
		Notify.toast(player, "Washed " .. CrimeRules.money(amount) .. ". " .. CrimeRules.money(clean) .. " clean, the house kept " .. CrimeRules.money(cut) .. ".", Color3.fromRGB(92, 196, 104))
		log(player.Name, "washed", amount, "->", clean)
	else
		send(player, { type = "washEnd", ok = false, why = why })
		if why then
			Notify.toast(player, why, Color3.fromRGB(226, 72, 72))
		end
	end
end

local function startWash(player: Player, e: Entry)
	if washing[player] then
		return
	end
	local c = CrimeService.data(player)
	local data = DataService.get(player)
	if not c or not data then
		return
	end
	if c.Dirty <= 0 then
		refuse(player, "Nothing to wash. Crime pays dirty cash; bring it here.")
		return
	end
	if PoliceService.heat(player) > W.MaxHeat then
		refuse(player, "Not with the cops on you. Lose the stars first.")
		return
	end
	local cut = CrimeRules.washCut(data.Level or 1, W)
	local seconds = CrimeRules.washSeconds(c.Dirty, W)
	local w: Wash = { amount = c.Dirty, cut = cut, seconds = seconds, started = os.clock(), at = e.pos }
	washing[player] = w
	w.sound = CrimeService.sound(Crime.Sounds.Wash, e.pos, { looped = true, volume = 0.35, speed = 0.55, life = seconds + 2 })
	local char = player.Character
	if char then
		char:SetAttribute("MTL_Action", "Count")
	end
	send(player, { type = "wash", seconds = seconds, amount = c.Dirty, cut = cut, clean = (CrimeRules.washPayout(c.Dirty, cut)) })
end

local function washTick()
	for player, w in washing do
		local r = root(player)
		local h = humanoid(player)
		if not player.Parent then
			washing[player] = nil
		elseif not r or not h or h.Health <= 0 then
			endWash(player, false, nil)
		elseif (r.Position - w.at).Magnitude > W.Radius + 3 then
			endWash(player, false, "You walked off. The wash stopped.")
		elseif PoliceService.heat(player) > W.MaxHeat then
			endWash(player, false, "The cops are on you. The wash stopped.")
		elseif os.clock() - w.started >= w.seconds then
			endWash(player, true, nil)
		end
	end
end

---------------------------------------------------------------- Marcus (tools + fence)

local function shopPayload(player: Player): any
	local data = DataService.get(player)
	local c = CrimeService.data(player)
	local tools = {}
	for _, id in Crime.ToolOrder do
		local t = Crime.Tools[id]
		table.insert(tools, {
			id = id,
			title = t.title,
			price = t.price,
			level = t.level,
			blurb = t.blurb,
			owned = CrimeService.hasTool(player, id),
		})
	end
	return {
		type = "shop",
		tools = tools,
		fence = if c then c.Fence else 0,
		cash = if data then data.Cash else 0,
		level = if data then data.Level else 1,
	}
end

local function openShop(player: Player)
	if not CrimeService.isCriminal(player) then
		Notify.toast(player, "Marcus looks you up and down. \"I don't know you.\"")
		return
	end
	send(player, shopPayload(player))
end

local function buyTool(player: Player, id: any)
	local t = type(id) == "string" and (Crime.Tools :: any)[id]
	local data = DataService.get(player)
	if not t or not data or not CrimeService.isCriminal(player) then
		return
	end
	local r = root(player)
	local at = CrimeService.point(Crime.FenceSite, "Fence")
	if not r or not at or (r.Position - at.Position).Magnitude > 16 then
		return
	end
	if CrimeService.hasTool(player, id) then
		return
	end
	if (data.Level or 1) < t.level then
		refuse(player, "Level " .. t.level .. " for the " .. string.lower(t.title) .. ".")
		return
	end
	-- plan -> validate -> apply -> record, no yield in between: spend() checks and debits in one step
	if not EconomyService.spend(player, t.price, "Tool:" .. id) then
		local have = if type(data.Cash) == "number" then data.Cash else 0
		refuse(player, "Need " .. CrimeRules.money(math.max(0, t.price - have)) .. " more clean cash. Marcus doesn't take dirty money.")
		return
	end
	data.Inventory.Items[id] = true
	DataService.push(player)
	Notify.toast(player, "Got the " .. string.lower(t.title) .. ".", Color3.fromRGB(92, 196, 104))
	send(player, shopPayload(player))
	publishReady(player)
	CrimeService.touchPrompts({ player })
end

local function fence(player: Player)
	local c = CrimeService.data(player)
	local r = root(player)
	local at = CrimeService.point(Crime.FenceSite, "Fence")
	if not c or not r or not at or (r.Position - at.Position).Magnitude > 16 then
		return
	end
	if c.Fence <= 0 then
		refuse(player, "Nothing to fence. Bring Marcus something from a house first.")
		return
	end
	local value = c.Fence
	c.Fence = 0
	CrimeService.addDirty(player, value, "Fence", at.Position)
	Notify.toast(player, "Marcus counts out " .. CrimeRules.money(value) .. " for the goods.", Color3.fromRGB(92, 196, 104))
	send(player, shopPayload(player))
	CrimeService.touchPrompts({ player })
end

-- Hooks for other services (airdrops, the pawn shop). giveTool: grants a crime tool for free (false if unknown or
-- already owned). takeFence: empties the goods waiting for Marcus and returns their $ value (caller pays out).
function CrimeService.giveTool(player: Player, id: string): boolean
	local data = DataService.get(player)
	if type(id) ~= "string" or not (Crime.Tools :: any)[id] or not data or CrimeService.hasTool(player, id) then
		return false
	end
	data.Inventory.Items[id] = true
	DataService.push(player)
	publishReady(player)
	CrimeService.touchPrompts({ player })
	return true
end

function CrimeService.fenceValue(player: Player): number
	local c = CrimeService.data(player)
	return if c then c.Fence else 0
end

function CrimeService.takeFence(player: Player): number
	local c = CrimeService.data(player)
	if not c or c.Fence <= 0 then
		return 0
	end
	local value = c.Fence
	c.Fence = 0
	send(player, shopPayload(player))
	CrimeService.touchPrompts({ player })
	return value
end

---------------------------------------------------------------- NPCs at the sites (clerks, Marcus, Benny)

-- Builds a rig from a look table (Missions.Actors shape) with CreateHumanoidModelFromDescription.
function CrimeService.buildRig(name: string, look: any): Model?
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor, desc.LeftArmColor, desc.RightArmColor = look.Skin, look.Skin, look.Skin
	desc.TorsoColor = look.Shirt
	desc.LeftLegColor, desc.RightLegColor = look.Pants, look.Pants
	if look.ShirtId and look.ShirtId ~= 0 then
		desc.Shirt = look.ShirtId
	end
	if look.PantsId and look.PantsId ~= 0 then
		desc.Pants = look.PantsId
	end
	if type(look.Hair) == "string" then
		desc.HairAccessory = look.Hair
	end
	if type(look.Hat) == "string" then
		desc.HatAccessory = look.Hat
	end
	if type(look.FaceAcc) == "string" then
		desc.FaceAccessory = look.FaceAcc
	end
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	desc:Destroy()
	if not ok or not model then
		warn("[MTL Crime] couldn't build rig", name, model)
		return nil
	end
	model.Name = name
	for _, d in model:GetDescendants() do
		if d:IsA("BaseScript") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanCollide = false
		end
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	if look.Height and look.Height ~= 1 then
		pcall(function()
			model:ScaleTo(look.Height)
		end)
	end
	return model
end

-- Puts a rig at a point, anchored at the root, standing on the point (y = floor).
function CrimeService.placeRig(m: Model, cf: CFrame, parent: Instance): Model
	local r = m:FindFirstChild("HumanoidRootPart") :: BasePart
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = d == r
			d.CanCollide = false
			d.Massless = true
		end
	end
	m.PrimaryPart = r
	local hum = m:FindFirstChildOfClass("Humanoid") :: Humanoid
	local hip = if hum then hum.HipHeight + r.Size.Y / 2 else 3
	r.CFrame = cf + Vector3.new(0, hip, 0)
	m.Parent = parent
	-- a slow idle so they breathe
	if hum then
		local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
		local a = Instance.new("Animation")
		a.AnimationId = "rbxassetid://2510196951"
		pcall(function()
			local t = (animator :: Animator):LoadAnimation(a)
			t.Looped = true
			t:Play(0.3)
		end)
	end
	return m
end

local npcFolder: Folder
local function spawnNPCs()
	local looks = Crime.Actors or {}
	local marcusAt = CrimeService.point(Crime.FenceSite, "Fence")
	if marcusAt and looks.Marcus then
		local m = CrimeService.buildRig("Marcus", looks.Marcus)
		if m then
			CrimeService.placeRig(m, marcusAt * CFrame.new(0, 0, -2.5) * CFrame.Angles(0, math.pi, 0), npcFolder)
		end
	end
	local bennyAt = CrimeService.point(W.Site, "Owner")
	if bennyAt and looks.Benny then
		local m = CrimeService.buildRig("Benny", looks.Benny)
		if m then
			CrimeService.placeRig(m, bennyAt, npcFolder)
		end
	end
end
CrimeService.npcFolder = function()
	return npcFolder
end

---------------------------------------------------------------- unlock texts from Dre

local function tellUnlocks(player: Player)
	local data = DataService.get(player)
	local c = CrimeService.data(player)
	local phone = sibling("PhoneService")
	if not data or not c or not phone or not CrimeService.isCriminal(player) then
		return
	end
	for _, id in Crime.MethodOrder do
		local m = Crime.method(id)
		if not c.Told[id] and (data.Level or 1) >= m.level then
			local text = Crime.Texts.Unlock[id]
			if text then
				c.Told[id] = true
				pcall(phone.text, player, "Dre", text)
				task.wait(1.5)
			end
		end
	end
end

---------------------------------------------------------------- remote

local function onAction(player: Player, msg: any)
	if type(msg) ~= "table" or type(msg.type) ~= "string" or not limiter:allow(player) then
		return
	end
	local t = msg.type
	if t == "holdBegin" and type(msg.id) == "string" then
		holdBegan[player] = holdBegan[player] or {}
		holdBegan[player][msg.id] = os.clock()
	elseif t == "prompt" and type(msg.id) == "string" then
		onPrompt(player, msg.id)
	elseif t == "mini" then
		onMini(player, msg)
	elseif t == "buyTool" then
		buyTool(player, msg.id)
	elseif t == "fence" then
		fence(player)
	elseif t == "washCancel" then
		endWash(player, false, nil)
	elseif t == "sync" then
		local c = CrimeService.data(player)
		send(player, { type = "dirty", dirty = if c then c.Dirty else 0, delta = 0 })
		sendPrompts(player)
		local jobs = CrimeService.jobs
		if jobs and jobs.resync then
			pcall(jobs.resync, player)
		end
	end
end

---------------------------------------------------------------- death / bust

local function onDied(player: Player)
	endWash(player, false, nil)
	CrimeService.cancelMini(player)
	local c = CrimeService.data(player)
	local r = root(player)
	if not c or c.Dirty <= 0 then
		return
	end
	-- GunService (downed -> finish): a gun death is either "Finished" (someone held E on you) or "BledOut". The bag
	-- drops either way; the finisher gets a head start on it (kill money pays on the finish, Urban Reload style).
	local char = player.Character
	local cause = char and char:GetAttribute("MTL_DeathCause")
	local finisher: Player? = nil
	if cause == "Finished" then
		local uid = char and char:GetAttribute("MTL_FinishedBy")
		finisher = if type(uid) == "number" then Players:GetPlayerByUserId(uid) else nil
	end
	local drop, keep = CrimeRules.dropSplit(c.Dirty, D.DropShare, D.DropMin)
	if drop > 0 and r then
		setDirty(player, keep, "Dropped")
		dropPickup(r.Position, drop, player)
		local p = pickups[#pickups]
		if finisher and p then
			p.first = finisher
			p.firstUntil = os.clock() + (D.FinisherHeadStart or 2)
		end
		send(player, { type = "dropped", amount = drop })
	end
end

PoliceService.onBust = function(player: Player): number
	endWash(player, false, nil)
	CrimeService.cancelMini(player)
	local jobs = CrimeService.jobs
	if jobs and jobs.abort then
		pcall(jobs.abort, player, "busted")
	end
	local c = CrimeService.data(player)
	if not c then
		return 0
	end
	local lost = math.floor(c.Dirty * D.BustShare)
	setDirty(player, c.Dirty - lost, "Busted")
	CrimeService.sound(Crime.Sounds.Cuffs, root(player) or Vector3.zero, { volume = 1 })
	return lost
end

---------------------------------------------------------------- init

function CrimeService.init()
	npcFolder = Instance.new("Folder")
	npcFolder.Name = "MTL_CrimeNPCs"
	npcFolder.Parent = workspace

	Net.get("CrimeAction").OnServerEvent:Connect(onAction)

	-- the laundromat counter + Marcus are global prompts (only criminals see them)
	task.defer(function()
		local counter = CrimeService.point(W.Site, "Counter")
		local washAt = if counter then counter.Position else (Crime.Sites :: any)[W.Site].at
		CrimeService.addGlobalPrompt({
			id = "wash",
			pos = washAt,
			action = "Wash cash",
			object = "Back counter",
			hold = 0.6,
			range = W.Radius,
			fn = startWash,
			visible = function(p: Player)
				return CrimeService.isCriminal(p) or CrimeService.dirty(p) > 0
			end,
		})
		local fenceAt = CrimeService.point(Crime.FenceSite, "Fence")
		if fenceAt then
			CrimeService.addGlobalPrompt({
				id = "marcus",
				pos = fenceAt.Position,
				action = "Talk",
				object = "Marcus",
				hold = 0,
				range = 9,
				fn = function(p: Player)
					openShop(p)
				end,
				visible = function(p: Player)
					return CrimeService.isCriminal(p)
				end,
			})
		else
			warn("[MTL Crime] no MTL_CrimeSites." .. Crime.FenceSite .. ".Fence point: run tools/BuildCrimeSites.lua")
		end
		spawnNPCs()
	end)

	-- the jobs (Stickup .. Heist)
	local jobsModule = script.Parent:FindFirstChild("CrimeJobs")
	if jobsModule then
		local ok, jobs = pcall(require, jobsModule)
		if ok and jobs then
			CrimeService.jobs = jobs
			local initOk, err = pcall(jobs.init, CrimeService)
			if not initOk then
				warn("[MTL Crime] CrimeJobs.init failed:", err)
			end
		else
			warn("[MTL Crime] CrimeJobs failed to load:", jobs)
		end
	end

	DataService.Ready:Connect(function(player: Player)
		local c = CrimeService.data(player)
		player:SetAttribute("MTL_Dirty", if c then c.Dirty else 0)
		if c and not D.LeaveKeeps then
			c.Dirty = 0
		end
		publishReady(player)
		refreshBag(player)
		dirtyPrompts[player] = true
		task.delay(20, tellUnlocks, player)
	end)
	EconomyService.LevelUp:Connect(function(player: Player)
		task.delay(4, tellUnlocks, player)
		dirtyPrompts[player] = true
	end)
	local phone = sibling("PhoneService")
	if phone and phone.PathChanged then
		phone.PathChanged:Connect(function(player: Player)
			dirtyPrompts[player] = true
			task.delay(3, tellUnlocks, player)
		end)
	end

	local function watch(player: Player)
		player.CharacterAdded:Connect(function(char)
			local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
			if hum then
				hum.Died:Connect(function()
					onDied(player)
				end)
			end
			char:WaitForChild("UpperTorso", 10)
			refreshBag(player)
			dirtyPrompts[player] = true
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		washing[player] = nil
		minis[player] = nil
		holdBegan[player] = nil
		sentAt[player] = nil
		dirtyPrompts[player] = nil
		extraPrompts[player] = nil
		local jobs = CrimeService.jobs
		if jobs and jobs.abort then
			pcall(jobs.abort, player, "left")
		end
	end)

	-- 5 Hz: pickups, washing, batched prompt sends
	task.spawn(function()
		while true do
			task.wait(0.2)
			pcall(pickupTick)
			pcall(washTick)
			for p in dirtyPrompts do
				dirtyPrompts[p] = nil
				if p.Parent then
					pcall(sendPrompts, p)
				end
			end
		end
	end)
	log("ready")
end

-- Studio: give yourself dirty cash / all tools / the Criminal path for a test.
function CrimeService.debug(player: Player, dirty: number?)
	assert(RunService:IsStudio(), "[MTL Crime] debug is Studio-only")
	local data = DataService.get(player)
	if not data then
		return
	end
	data.Path = "Criminal"
	player:SetAttribute("MTL_Path", "Criminal")
	for id in Crime.Tools do
		data.Inventory.Items[id] = true
	end
	if (data.Level or 1) < 12 then
		EconomyService.addXP(player, 40000, "Debug")
	end
	if dirty then
		CrimeService.addDirty(player, dirty, "Debug")
	end
	local c = CrimeService.data(player)
	if c then
		table.clear(c.Last)
	end
	publishReady(player)
	CrimeService.touchPrompts({ player })
	DataService.push(player)
end

return CrimeService
