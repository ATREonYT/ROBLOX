--[[
	Plays whole games of Huzz Valley offline: the REAL server scripts (RoundService, PowerService, RoundRules,
	GirlRoll and the configs) run against small fake services on a virtual clock, with bot players who run,
	chase, stab, use powers and huss. After every frame it checks the rules the owner asked for and prints
	what happened. Run from the repo root:  lune run huzz-valley/tools/sim/round_sim.luau
	It can't show physics, animation or UI: those need Studio. It does prove the round logic and the glue
	between the services: stages, the vote -> map swap -> roller -> rounds -> winner loop, roles, knives,
	the start wall, stabs, shields, traps, charm waves, hussing, leaving and joining.
]]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local Vector3, CFrame, Color3 = roblox.Vector3, roblox.CFrame, roblox.Color3
-- Roblox's CFrame.lookAt (Lune's faces the other way).
local function lookAt(pos, target)
	if (target - pos).Magnitude < 1e-4 then
		return CFrame.new(pos) -- (no direction: a NaN here would stick to the body for good)
	end
	local look = (target - pos).Unit
	local right = look:Cross(Vector3.new(0, 1, 0)).Unit
	return CFrame.fromMatrix(pos, right, right:Cross(look), -look)
end
-- HUZZ_SRC=<folder>/ runs another copy of src (e.g. an older commit, for before/after numbers)
local SRC = require("@lune/process").env.HUZZ_SRC or "huzz-valley/src/"

------------------------------------------------------------------ virtual clock and task library
local clock = 0
local queue = {} -- { at, seq, co, args }
local seq = 0
local errors = {}

local function schedule(at, co, ...)
	seq += 1
	table.insert(queue, { at = at, seq = seq, co = co, args = table.pack(...) })
end

local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		table.insert(errors, debug.traceback(co, tostring(err)))
	end
end

local task = {}
function task.wait(t)
	local start = clock
	schedule(clock + math.max(t or 0, 1 / 60), coroutine.running())
	coroutine.yield()
	return clock - start
end
function task.spawn(fn, ...)
	local co = if type(fn) == "thread" then fn else coroutine.create(fn)
	resume(co, ...)
	return co
end
function task.defer(fn, ...)
	local co = coroutine.create(fn)
	schedule(clock, co, ...)
	return co
end
function task.delay(t, fn, ...)
	local co = coroutine.create(fn)
	schedule(clock + (t or 0), co, ...)
	return co
end

local function runUntil(t)
	while true do
		local best, bi = nil, nil
		for i, item in queue do
			if not best or item.at < best.at or (item.at == best.at and item.seq < best.seq) then
				best, bi = item, i
			end
		end
		if not best or best.at > t then
			break
		end
		table.remove(queue, bi)
		clock = math.max(clock, best.at)
		if coroutine.status(best.co) == "suspended" then
			resume(best.co, table.unpack(best.args, 1, best.args.n))
		end
	end
	clock = t
end

------------------------------------------------------------------ signals and fake instances
local function Signal()
	local s = { handlers = {} }
	function s:Connect(fn)
		local h = { fn = fn }
		table.insert(self.handlers, h)
		return { Disconnect = function() h.dead = true end }
	end
	function s:Once(fn)
		local conn
		conn = self:Connect(function(...)
			conn.Disconnect()
			fn(...)
		end)
		return conn
	end
	function s:Fire(...)
		for _, h in table.clone(self.handlers) do
			if not h.dead then
				task.spawn(h.fn, ...)
			end
		end
	end
	function s:Wait()
		return task.wait(1 / 30)
	end
	return s
end

local Inst = {}
local function new(className, props)
	local o = { _class = className, _children = {}, _attrs = {}, _attrSignals = {}, _props = {} }
	setmetatable(o, Inst)
	o._props.Name = className
	for k, v in props or {} do
		o[k] = v
	end
	return o
end
Inst.__index = function(o, k)
	local own = rawget(o, "_props")[k]
	if own ~= nil and type(own) == "function" then
		return own -- a fake service's own method wins
	elseif Inst[k] then
		return Inst[k]
	elseif k == "ClassName" then
		return rawget(o, "_class")
	elseif k == "Parent" then
		return rawget(o, "_parent")
	elseif k == "Position" and rawget(o, "_props").CFrame then
		return rawget(o, "_props").CFrame.Position
	end
	local v = rawget(o, "_props")[k]
	if v == nil then
		local child = Inst.FindFirstChild(o, k)
		if child then
			return child
		end
	end
	return v
end
Inst.__newindex = function(o, k, v)
	if k == "Parent" then
		local old = rawget(o, "_parent")
		if old then
			local list = rawget(old, "_children")
			local i = table.find(list, o)
			if i then
				table.remove(list, i)
			end
		end
		rawset(o, "_parent", v)
		if v then
			table.insert(rawget(v, "_children"), o)
		end
	elseif k == "Position" then
		rawget(o, "_props").CFrame = CFrame.new(v)
	else
		rawget(o, "_props")[k] = v
	end
end
function Inst:IsA(c)
	return self._class == c or (c == "BasePart" and (self._class == "Part" or self._class == "WedgePart"))
		or (c == "LuaSourceContainer" and self._class == "Script")
end
function Inst:FindFirstChild(name, recursive)
	for _, c in self._children do
		if c.Name == name then
			return c
		end
		if recursive then
			local d = c:FindFirstChild(name, true)
			if d then
				return d
			end
		end
	end
	return nil
end
function Inst:WaitForChild(name)
	return self:FindFirstChild(name)
end
function Inst:FindFirstChildOfClass(c)
	for _, ch in self._children do
		if ch._class == c then
			return ch
		end
	end
	return nil
end
function Inst:GetChildren()
	return table.clone(self._children)
end
function Inst:GetDescendants()
	local out = {}
	for _, c in self._children do
		table.insert(out, c)
		for _, d in c:GetDescendants() do
			table.insert(out, d)
		end
	end
	return out
end
function Inst:ClearAllChildren()
	for _, c in self:GetChildren() do
		c:Destroy()
	end
end
function Inst:Destroy()
	self.Parent = nil
	rawset(self, "_destroyed", true)
	for _, c in self:GetChildren() do
		c:Destroy()
	end
end
function Inst:SetAttribute(k, v)
	if self._attrs[k] ~= v then
		self._attrs[k] = v
		local s = self._attrSignals[k]
		if s then
			s:Fire()
		end
	end
end
function Inst:GetAttribute(k)
	return self._attrs[k]
end
function Inst:GetAttributeChangedSignal(k)
	self._attrSignals[k] = self._attrSignals[k] or Signal()
	return self._attrSignals[k]
end
function Inst:PivotTo(cf)
	local root = self:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = cf
	end
end
function Inst:GetBoundingBox()
	return self._props.CFrame or CFrame.new(), Vector3.new(2, 5, 1)
end

------------------------------------------------------------------ one simulated server
local function simulate(opts)
	clock, queue, errors = 0, {}, {}
	math.randomseed(opts.seed or 1)
	local rng = { NextNumber = function() return math.random() end }
	local stats = { stages = {}, games = 0, wins = 0, stabs = 0, tags = 0, powers = {}, blocks = 0, sprung = 0, charmed = 0, husses = 0, kept = 0, safeOutside = 0,
		rescues = 0, picks = 0, heroes = 0, heroSurvived = 0, timeoutPicks = 0, runnerWins = 0, catcherWins = 0,
		-- loop audit (tools/sim/round_sim.luau audit): seconds per stage, player-seconds per kind of wait, rounds
		stageTime = {}, wait = {}, rounds = 0, runTimeouts = 0, runTime = 0, heroTimeouts = 0, maxRoundGames = 0,
		gameLengths = {}, roundsPerGame = {}, hurries = 0, heroEarly = 0, lastAlone = 0 }
	local problems = {}
	local seen = {}
	local function problem(msg)
		local kind = msg:gsub("%d", "")
		if seen[kind] then
			return -- each kind of problem once
		end
		seen[kind] = true
		if #problems < 30 then
			table.insert(problems, string.format("t=%.1f %s", clock, msg))
		end
	end

	-- Services
	local workspace = new("Workspace")
	function workspace:GetServerTimeNow()
		return 1000 + clock
	end
	local ReplicatedStorage = new("ReplicatedStorage")
	local Players = new("Players")
	Players.PlayerAdded, Players.PlayerRemoving = Signal(), Signal()
	function Players:GetPlayers()
		local list = {}
		for _, p in self._children do
			table.insert(list, p)
		end
		return list
	end
	local RunService = new("RunService")
	RunService.Heartbeat = Signal()
	function RunService:IsStudio()
		return opts.studio == true
	end
	local StarterPlayer = new("StarterPlayer", { CharacterWalkSpeed = 16, CharacterJumpHeight = 7.2, CharacterJumpPower = 50 })
	local HttpService = new("HttpService")
	function HttpService:JSONEncode(v)
		return serde.encode("json", v)
	end
	local services = { Workspace = workspace, ReplicatedStorage = ReplicatedStorage, Players = Players, RunService = RunService, StarterPlayer = StarterPlayer, HttpService = HttpService }
	local game = new("DataModel")
	function game:GetService(name)
		return services[name] or new(name)
	end

	-- Remotes
	local remotes = {}
	local roundEvents = {}
	local Net = {
		get = function(name)
			if not remotes[name] then
				local r = new("RemoteEvent", { Name = name })
				r.OnServerEvent = Signal()
				function r:FireAllClients(kind, data)
					table.insert(roundEvents, { kind = kind, data = data, t = clock })
				end
				function r:FireClient(_, kind, data)
					table.insert(roundEvents, { kind = kind, data = data, t = clock, one = true })
				end
				remotes[name] = r
			end
			return remotes[name]
		end,
	}
	local Round = Net.get("Round")

	-- Real shared modules
	local function loadShared(path, extraEnv)
		-- (Lune copies the environment's keys; a metatable on it is ignored. Built-ins come along anyway.)
		local env = extraEnv or {}
		env.Vector3, env.CFrame, env.Color3 = Vector3, CFrame, Color3
		return luau.load(fs.readFile(SRC .. path), { environment = env })()
	end
	local Config = loadShared("ReplicatedStorage/Shared/Config/Round.lua")
	if opts.config then
		opts.config(Config)
	end
	local Carry = loadShared("ReplicatedStorage/Shared/Config/Carry.lua")
	local Powers = loadShared("ReplicatedStorage/Shared/Config/Powers.lua")
	local RoundRules = loadShared("ReplicatedStorage/Shared/RoundRules.lua")
	local GirlRoll = loadShared("ReplicatedStorage/Shared/GirlRoll.lua")
	local SecretReveal = loadShared("ReplicatedStorage/Shared/SecretReveal.lua")

	-- Fake map: ZoneA on the left, ZoneB on the right, Middle between, the lobby far away.
	local function box(x, z, sx, sz)
		return new("Part", { CFrame = CFrame.new(x, 4, z), Size = Vector3.new(sx, 8, sz) })
	end
	local zones = {}
	local loads, unloads, wallOn, goalShown, gateOn = 0, 0, nil, nil, nil
	local catcherWallsOn = false
	local MapService = {
		zones = zones,
		maps = { { name = "Base_Map", display = "Base" }, { name = "Halloween_Map", display = "Halloween" }, { name = "BasketBall_Map", display = "BasketBall" } },
	}
	zones.Lobby = box(0, 300, 60, 60)
	function MapService.init() end
	local boundsOn = false
	function MapService.setBounds(on) boundsOn = on end
	-- One lobby per map (the owner's place): each map's lobby sits somewhere else, so moving everyone runs.
	local lobbyOf = {}
	for i, m in MapService.maps do
		lobbyOf[m] = box(i * 400, 300, 60, 60)
	end
	function MapService.useLobbyFor(entry)
		local lobby = lobbyOf[entry]
		if not lobby or lobby == zones.Lobby then return false end
		zones.Lobby = lobby
		return true
	end
	function MapService.lobbySpawn()
		return zones.Lobby.CFrame.Position
	end
	function MapService.byName(n)
		for _, m in MapService.maps do
			if m.name == n then
				return m
			end
		end
	end
	local last
	function MapService.candidates()
		local pool = {}
		for _, m in MapService.maps do
			if m ~= last then
				table.insert(pool, m)
			end
		end
		return pool[1], pool[2]
	end
	function MapService.load(entry)
		MapService.unload(true)
		loads += 1
		last = entry
		if opts.realField then
			-- the owner's maps (tools/check_maps.luau): safe lines about 280 studs apart, 165 long
			zones.ZoneA, zones.ZoneB, zones.Middle = box(-150, 0, 20, 165), box(150, 0, 20, 165), box(0, 0, 280, 165)
		else
			zones.ZoneA, zones.ZoneB, zones.Middle = box(-60, 0, 20, 80), box(60, 0, 20, 80), box(0, 0, 100, 80)
		end
		MapService.current = entry
	end
	function MapService.unload(fromLoad)
		if not fromLoad then
			unloads += 1
		end
		zones.ZoneA, zones.ZoneB, zones.Middle = nil, nil, nil
	end
	function MapService.inZone(zone, position)
		local p = zone.CFrame:PointToObjectSpace(position)
		local half = zone.Size * 0.5
		return math.abs(p.X) <= half.X and math.abs(p.Z) <= half.Z and p.Y >= -half.Y - 4 and p.Y <= half.Y + 14
	end
	function MapService.keepIn(zone, position)
		if MapService.inZone(zone, position) then
			return nil
		end
		local p = zone.CFrame:PointToObjectSpace(position)
		local half = zone.Size * 0.5 - Vector3.new(1.5, 0, 1.5)
		return zone.CFrame:PointToWorldSpace(Vector3.new(math.clamp(p.X, -half.X, half.X), p.Y, math.clamp(p.Z, -half.Z, half.Z)))
	end
	function MapService.ground()
		return 0
	end
	function MapService.spot(zone, lookAt, spread)
		local half = zone.Size * 0.5
		local s = spread or math.huge
		local x = (rng:NextNumber() * 2 - 1) * math.min(half.X - 3, s)
		local z = (rng:NextNumber() * 2 - 1) * math.min(half.Z - 3, s)
		local pos = zone.CFrame.Position + Vector3.new(x, -4 + 3.2, z)
		return CFrame.new(pos)
	end
	function MapService.goalFor(round)
		return if round % 2 == 1 then "ZoneB" else "ZoneA"
	end
	function MapService.startFor(round)
		return if round % 2 == 1 then "ZoneA" else "ZoneB"
	end
	function MapService.holdStart(name, on)
		wallOn = if on then name else nil
	end
	function MapService.showGoal(name)
		goalShown = name
	end
	function MapService.holdGoal(name, on)
		gateOn = if on then name else nil
	end
	function MapService.setSafe() end
	function MapService.setCatcher() end
	function MapService.holdCatchers(on)
		catcherWallsOn = on
	end
	-- As MapService.pushOut: a point inside a zone goes back over its middle-facing edge, 1.5 studs onto the field.
	function MapService.pushOut(zone, position)
		if not (zone and zones.Middle and MapService.inZone(zone, position)) then
			return nil
		end
		local d = zones.Middle.CFrame.Position - zone.CFrame.Position
		local out = Vector3.new(d.X, 0, d.Z).Unit
		local centre = zone.CFrame.Position + out * (zone.Size.X / 2)
		local k = (position - centre):Dot(out)
		if k >= 0 then
			return nil
		end
		return position + out * (1.5 - k)
	end
	-- As MapService.lineup: a row just behind the zone's edge that faces the middle, looking across.
	function MapService.lineup(zoneName, count)
		local zone, middle = zones[zoneName], zones.Middle
		local d = middle.CFrame.Position - zone.CFrame.Position
		local out = Vector3.new(d.X, 0, d.Z).Unit
		local along = Vector3.new(-out.Z, 0, out.X)
		local depth = math.abs(out.X) * zone.Size.X / 2 + math.abs(out.Z) * zone.Size.Z / 2
		local centre = zone.CFrame.Position + out * depth + Vector3.new(0, -4, 0)
		local spots = {}
		for i = 1, count do
			local pos = centre - out * 2.5 + along * ((i - 1 - (count - 1) / 2) * 4) + Vector3.new(0, 3.2, 0)
			spots[i] = lookAt(pos, pos + out)
		end
		return lookAt(centre, centre + out), 60, spots
	end

	-- Fake girls: the real fair roll on a small catalogue.
	local catalog = {}
	for i, r in { "Common", "Common", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Secret" } do
		table.insert(catalog, { id = "girl" .. i, name = r .. " Girl " .. i, rarity = r, key = "G" .. i })
	end
	local function rand()
		return rng:NextNumber()
	end
	local GirlService = { catalog = catalog }
	function GirlService.init() end
	function GirlService.roll()
		return GirlRoll.pick(catalog, Config.Rarities, rand)
	end
	function GirlService.strip(w, n, at)
		return GirlRoll.strip(catalog, Config.Rarities, w, n, at, rand), GirlRoll.odds(catalog, Config.Rarities)
	end
	function GirlService.prepare()
		task.wait(0.4)
	end
	function GirlService.rarity(n)
		return { Name = n, Color = Color3.new(1, 1, 1) }
	end
	local showcases = 0
	function GirlService.showcase(_, at)
		showcases += 1
		local m = new("Model", { Name = "HuzzShowcase", CFrame = CFrame.new(at) })
		m.Parent = workspace
		function m:GetPivot()
			return self.CFrame
		end
		return m
	end
	local prizeModel
	function GirlService.display(_, at)
		prizeModel = new("Model", { CFrame = CFrame.new(at) })
		prizeModel.Parent = workspace
		return prizeModel
	end

	-- Fake carry: who has her, and how.
	local carried = {}
	local CarryService = {}
	function CarryService.get(p)
		return carried[p]
	end
	function CarryService.position(p)
		local root = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		return root and root.Position
	end
	function CarryService.remove(p)
		carried[p] = nil
	end
	function CarryService.removeAll()
		carried = {}
	end
	function CarryService.give(p)
		local m = new("Model", { Name = "Carried" })
		m:SetAttribute("Carrier", p.UserId)
		carried[p] = m
		return m
	end
	function CarryService.follow(p)
		local m = new("Model", { Name = "Follower" })
		m:SetAttribute("Follow", p.UserId)
		carried[p] = m
		return m
	end
	function CarryService.setMood() end

	local saves = {}
	local DataService = {}
	function DataService.waitFor(p)
		return saves[p]
	end
	function DataService.get(p)
		return saves[p] and { Data = saves[p] } -- (what RoundService reads: Characters for a repeat girl, Wear)
	end
	function DataService.update(p, fn)
		saves[p] = saves[p] or { Stats = {}, Characters = {} }
		fn(saves[p])
	end
	local downed = {}
	local KnockdownService = {}
	function KnockdownService.down(p)
		downed[p] = true
	end
	function KnockdownService.isDown(p)
		return downed[p] == true
	end
	function KnockdownService.upAll()
		downed = {}
	end
	function KnockdownService.up(p)
		downed[p] = nil
	end
	local MapVoteService = {}
	function MapVoteService.run(a, b, seconds)
		task.wait(seconds)
		return if rng:NextNumber() < 0.5 then a else b
	end
	local KnifeService = {}
	function KnifeService.give(c)
		c._knife = true
	end
	function KnifeService.take(c)
		if c then
			c._knife = nil
		end
	end
	function KnifeService.giveBack(c)
		c._backKnife = true
	end
	function KnifeService.takeBack(c)
		c._backKnife = nil
	end
	function KnifeService.has(c)
		return c._knife == true
	end
	local SafetyService = { clean = function() end }
	-- Name tags: remembers what each player's tag says, for the checks.
	local tags = {}
	local NameTagService = { set = function(player, look, badge, rescue)
		tags[player] = { look = look, badge = badge, rescue = rescue }
	end, bot = function() end }

	-- The module tree the scripts require from.
	local baseEnv = {
		game = game, workspace = workspace, task = task, Vector3 = Vector3, CFrame = CFrame, Color3 = Color3,
		Instance = { new = function(c) return new(c) end },
		Enum = roblox.Enum, UDim2 = roblox.UDim2, UDim = roblox.UDim,
		Font = { new = function() return {} end },
		ColorSequence = { new = function() return {} end }, NumberSequence = { new = function() return {} end },
		os = setmetatable({ clock = function() return clock end }, { __index = os }),
		warn = function(...)
			local msg = table.concat(table.pack(...), " ")
			if msg:find("stopped by an error") then
				problem("GAME ERROR: " .. msg)
			end
		end,
		print = function() end,
	}
	local PowerService
	local modules = {
		MapService = MapService, GirlService = GirlService, CarryService = CarryService, DataService = DataService,
		KnockdownService = KnockdownService, MapVoteService = MapVoteService, KnifeService = KnifeService, SafetyService = SafetyService,
		NameTagService = NameTagService,
		SpinService = { boost = function() return 1 end }, -- (the Spin the Wheel's x2 Coins: none in the sim)
		ProgressService = { gameXP = function(_, won, t) return 40 + (if won then 40 else 0), nil end },
	}
	local Shared = { Config = { Round = Config, Carry = Carry, Powers = Powers }, RoundRules = RoundRules, Net = Net, GirlRoll = GirlRoll, SecretReveal = SecretReveal,
		KnifeLook = { pick = function() return nil end } } -- (which knife you wear: the default one in the sim)
	local sharedNode = setmetatable({}, { __index = function(_, k)
		return Shared[k]
	end })
	function ReplicatedStorage:WaitForChild(name)
		return if name == "Shared" then sharedNode else nil
	end
	ReplicatedStorage.Shared = sharedNode
	local function req(m)
		return m -- modules are passed around as the loaded tables themselves
	end
	local function loadScript(path)
		local env = table.clone(baseEnv)
		env.script = { Parent = setmetatable({}, { __index = function(_, k) return modules[k] end }) }
		env.require = req
		return luau.load(fs.readFile(SRC .. path), { environment = env, debugName = path })
	end
	PowerService = loadScript("ServerScriptService/HuzzServer/PowerService.lua")()
	modules.PowerService = PowerService
	-- The Practice Bot: the real module with a stand-in body that botFrame walks where it's told.
	local practice = nil
	local PracticeBot = loadScript("ServerScriptService/HuzzServer/PracticeBot.lua")()
	PracticeBot.makeBody = function()
		local m = new("Model", { Name = "Practice Bot" })
		new("Part", { Name = "HumanoidRootPart", CFrame = CFrame.new(0, 3, 0) }).Parent = m
		new("Part", { Name = "Head" }).Parent = m
		new("Humanoid", { Health = 100, WalkSpeed = 0, MoveTo = function(self, at) rawget(self, "_props").Goal = at end }).Parent = m
		practice = m
		return m
	end
	modules.PracticeBot = PracticeBot

	-- Players and their bots
	local nextId = 100
	local bots = {}
	local function addPlayer(kind)
		nextId += 1
		local p = new("Player", { Name = "Bot" .. nextId, DisplayName = "Bot" .. nextId, UserId = nextId })
		p.CharacterAdded = Signal()
		local c = new("Model", { Name = p.Name })
		local root = new("Part", { Name = "HumanoidRootPart", CFrame = CFrame.new(0, 3, 300) })
		root.Parent = c
		new("Part", { Name = "Head" }).Parent = c
		local h = new("Humanoid", { Health = 100, WalkSpeed = 16, RootPart = root })
		h.Died = Signal()
		h.Parent = c
		p.Character = c
		p.Parent = Players
		bots[p] = { kind = kind or "normal", lastStab = -99, seed = rng:NextNumber() }
		Players.PlayerAdded:Fire(p)
		return p
	end
	local function removePlayer(p)
		Players.PlayerRemoving:Fire(p)
		p.Parent = nil
		bots[p] = nil
	end

	-- Watch every message the server sends to clients.
	local function watchEvents()
		for _, e in roundEvents do
			if e.kind == "Caught" then
				stats.tags += 1
				if e.data.bot then stats.botTags = (stats.botTags or 0) + 1 end
			elseif e.kind == "Stab" then
				stats.stabs += 1
			elseif e.kind == "Power" then
				stats.powers[e.data.name] = (stats.powers[e.data.name] or 0) + 1
				if e.data.name == "ShieldPop" then stats.blocks += 1 end
				if e.data.name == "TrapSprung" then stats.sprung += 1 end
			elseif e.kind == "Rescued" then
				stats.rescues += 1
			elseif e.kind == "Announce" and type(e.data.text) == "string" and e.data.text:find("made the Hero run") then
				stats.heroSurvived += 1
			elseif e.kind == "Announce" and type(e.data.text) == "string" and e.data.text:find("ran out of time") then
				stats.heroTimeouts += 1
			elseif e.kind == "Announce" and type(e.data.text) == "string" and e.data.text:find("didn't go") then
				stats.heroEarly += 1
			elseif e.kind == "Announce" and type(e.data.text) == "string" and e.data.text:find("Hurry") then
				stats.hurries += 1
			elseif e.kind == "Announce" and type(e.data.text) == "string" and e.data.text:find("last runner") then
				stats.lastAlone += 1
			elseif e.kind == "Win" then
				stats.wins += 1
				if e.data.team == "Runners" then stats.runnerWins += 1 elseif e.data.team == "Catchers" then stats.catcherWins += 1 end
				if e.data.bot then
					stats.botWins = (stats.botWins or 0) + 1
					if e.data.winner then problem("the Practice Bot won but a player got the girl") end
				end
				if e.data.winner then
					local p = nil
					for q in bots do
						if q.UserId == e.data.winner then p = q end
					end
					task.defer(function()
						if p and not (saves[p] and next(saves[p].Characters)) then
							problem("winner " .. e.data.winner .. " has no girl saved")
						end
					end)
				end
			end
		end
		table.clear(roundEvents)
	end

	-- Bots: one frame of moving and deciding, then the checks.
	local ALLOWED = {
		Waiting = { Voting = true, Intermission = true },
		Voting = { Rolling = true, Waiting = true },
		Intermission = { Rolling = true, Waiting = true },
		Rolling = { Lineup = true, GameOver = true, Waiting = true, Voting = true, Reveal = true },
		Reveal = { Lineup = true, GameOver = true, Waiting = true }, -- (a Secret girl's arrival cutscene)
		Lineup = { Picking = true, Countdown = true, GameOver = true },
		Picking = { Chosen = true, Countdown = true, RoundOver = true, GameOver = true }, -- (the picked runner left)
		Chosen = { HeroRun = true, Countdown = true },
		HeroRun = { Countdown = true, RoundOver = true, GameOver = true },
		Countdown = { Running = true },
		Running = { RoundOver = true, GameOver = true },
		RoundOver = { Lineup = true, GameOver = true },
		GameOver = { Waiting = true, Voting = true },
	}
	local lastStage = nil
	local function stage()
		return Round:GetAttribute("Stage")
	end
	-- What a player is doing this frame, for the loop audit: "play" (can run, chase or rescue), or a kind of waiting.
	local function waitKind(p, st)
		local role, status = p:GetAttribute("HuzzRole"), p:GetAttribute("HuzzStatus")
		if st == "Waiting" or st == "Voting" or st == "Intermission" then
			return "lobby"
		elseif role ~= "Runner" and role ~= "Catcher" and st ~= "Rolling" and st ~= "Reveal" then
			return "lateJoin" -- joined mid-game: waits in the lobby for the next one
		elseif st == "Running" or st == "HeroRun" then
			if role == "Catcher" then
				return "play"
			elseif status == "Safe" then
				return "safe"
			elseif status == "Downed" then
				return "down"
			elseif st == "HeroRun" and not p:GetAttribute("HuzzHero") then
				return "heroWatch"
			end
			return "play"
		end
		return "cutscene" -- roller, line-up, pick, countdown, round over, game over
	end
	local stageStart, gameStart, gameRounds = 0, nil, 0
	local function botFrame(dt)
		local st = stage()
		if st then
			stats.stageTime[st] = (stats.stageTime[st] or 0) + dt
		end
		for p, bot in bots do
			if bot.kind ~= "afk" then
				local k = waitKind(p, st)
				stats.wait[k] = (stats.wait[k] or 0) + dt
			end
		end
		if st ~= lastStage then
			local spent = clock - stageStart
			stageStart = clock
			if lastStage == "Running" then
				stats.runTime += spent
				if spent >= Config.RoundTime - 0.2 then
					stats.runTimeouts += 1
				end
			end
			if st == "Rolling" then
				gameStart, gameRounds = clock, 0
			elseif st == "Lineup" then
				stats.rounds += 1
				gameRounds += 1
			elseif lastStage == "GameOver" and gameStart then
				table.insert(stats.gameLengths, clock - gameStart)
				table.insert(stats.roundsPerGame, gameRounds)
				if gameRounds >= Config.MaxRounds then
					stats.maxRoundGames += 1
				end
				gameStart = nil
			end
			table.insert(stats.stages, st)
			if lastStage and not (ALLOWED[lastStage] and ALLOWED[lastStage][st]) then
				problem(`stage {lastStage} -> {st} is not allowed`)
			end
			if st == "Rolling" then
				local raw = Round:GetAttribute("RollData")
				local ok, roll = pcall(serde.decode, "json", raw or "")
				if not (ok and roll and #roll.cells == Config.Roll.Cells and roll.cells[roll.stop] and roll.cells[roll.stop].key) then
					problem("roller data missing or wrong: " .. tostring(raw))
				end
			elseif lastStage == "Rolling" and (Round:GetAttribute("RollData") or "") ~= "" then
				problem("roller data not cleared after the roll")
			end
			if lastStage == "Rolling" then
				stats.games += 1
			end
			if st == "Picking" then
				stats.picks += 1
				local id = Round:GetAttribute("PickId")
				local picked = nil
				for q in bots do if q.UserId == id then picked = q end end
				if not picked then
					problem("Picking with no picked player: " .. tostring(id))
				elseif picked:GetAttribute("HuzzRole") ~= "Runner" or picked:GetAttribute("HuzzStatus") ~= "Active" then
					problem("the picked player isn't an Active runner")
				end
			elseif st == "HeroRun" then
				stats.heroes += 1
				-- only the Hero (and catchers) may move; everyone else waits on the line
				for q in bots do
					local h = q.Character and q.Character:FindFirstChildOfClass("Humanoid")
					if q:GetAttribute("HuzzRole") == "Runner" and not q:GetAttribute("HuzzHero") and h and h.WalkSpeed ~= 0 then
						problem(`{q.Name} can move during someone else's Hero run`)
					end
				end
			elseif st == "Chosen" and lastStage == "Picking" and (Round:GetAttribute("PickChoice") or "") == "" then
				problem("Chosen with no choice")
			end
			if st == "Lineup" or st == "Countdown" then
				task.defer(function()
					for q in bots do
						local h = q.Character and q.Character:FindFirstChildOfClass("Humanoid")
						if q:GetAttribute("HuzzStatus") == "Active" and h and h.WalkSpeed ~= 0 then
							problem(`{q.Name} can move during {st}`)
						end
					end
				end)
			end
			if st == "Running" then
				-- The start wall must have kept every runner on their side.
				for p in bots do
					if p:GetAttribute("HuzzStatus") == "Active" then
						local root = p.Character.HumanoidRootPart
						local start = zones[MapService.startFor(Round:GetAttribute("Round"))]
						local back = MapService.keepIn(start, root.Position)
						-- (3 studs: this runs a frame or two after GO, when a fast runner is already a step over the line;
						-- anyone who got round the wall is far further out)
						if back and (back - root.Position).Magnitude > 3 then
							problem(`{p.Name} left the start zone before GO`)
						end
					end
				end
			end
			lastStage = st
		end
		watchEvents()
		local shown = 0
		for _, c in workspace:GetChildren() do
			if c.Name == "HuzzShowcase" then shown += 1 end
		end
		local held = (Round:GetAttribute("HolderId") or 0) ~= 0
		if (st == "Countdown" or st == "Running") and shown ~= (if held then 0 else 1) then
			problem(`{shown} big girls over the map during a game (should be {if held then 0 else 1}: she's {if held then "held" else "free"})`)
		elseif (st == "Voting" or st == "Waiting") and shown ~= 0 then
			problem("the big girl stayed after the game")
		end
		-- The Practice Bot walks where its Humanoid was told, at its WalkSpeed; it's only there during a game.
		if practice and practice.Parent then
			if st == "Voting" or st == "Waiting" or st == "Intermission" then
				problem("the Practice Bot stayed after the game")
			end
			local h, root = practice:FindFirstChildOfClass("Humanoid"), practice.HumanoidRootPart
			local goal = h.Goal
			if h.WalkSpeed > 0 and Config.Bot.MinSpeed then
				-- it adapts to the kids (Config.Bot Step), always between MinSpeed and MaxSpeed
				stats.botSpeeds = stats.botSpeeds or {}
				stats.botSpeeds[h.WalkSpeed] = true
				if h.WalkSpeed < Config.Bot.MinSpeed or h.WalkSpeed > Config.Bot.MaxSpeed then
					problem("the Practice Bot runs at " .. h.WalkSpeed)
				end
			end
			if goal and h.WalkSpeed > 0 then
				stats.botMoves = (stats.botMoves or 0) + 1
				local d = goal - root.Position
				d = Vector3.new(d.X, 0, d.Z)
				if d.Magnitude > 0.3 then
					root.CFrame = CFrame.new(root.Position + d.Unit * math.min(d.Magnitude, h.WalkSpeed * dt))
				end
			elseif h.WalkSpeed > 0 and st ~= "Running" and st ~= "HeroRun" then
				problem("the Practice Bot moves outside play (" .. tostring(st) .. ")")
			end
		end
		local now = 1000 + clock
		-- Catchers see where a runner was about 0.33 s ago (a kid's reaction plus the network): a trail of 10 frames.
		for q, b in bots do
			local r = q.Character and q.Character:FindFirstChild("HumanoidRootPart")
			b.trail = b.trail or {}
			if r then
				table.insert(b.trail, r.Position)
				if #b.trail > 10 then table.remove(b.trail, 1) end
			end
		end
		local function seen(q)
			local b = bots[q]
			return b and b.trail and b.trail[1] or q.Character.HumanoidRootPart.Position
		end
		for p, bot in bots do
			local c = p.Character
			local h = c and c:FindFirstChildOfClass("Humanoid")
			local root = c and c.HumanoidRootPart
			local role, status = p:GetAttribute("HuzzRole"), p:GetAttribute("HuzzStatus")
			if not (h and root) then
				continue
			end
			-- Knives: catchers in a running game hold one, nobody else.
			local playing = st == "Countdown" or st == "Running" or st == "RoundOver" or st == "Lineup" or st == "HeroRun"
			if playing and role == "Catcher" and not c._knife and Config.TagMode == "Stab" then
				problem(`catcher {p.Name} has no knife`)
			elseif role ~= "Catcher" and c._knife then
				problem(`{role} {p.Name} holds a knife`)
			end
			-- The power bar (Screens/PowerBar: shown only while PowerReady1 is set) is there for everyone still playing
			-- in a run, also the run after a Hero's solo run (owner, Oct 18: "why dont you have any buttons after?").
			if (st == "Running" or st == "HeroRun") and (role == "Runner" or role == "Catcher") and status ~= "Downed" and status ~= "Safe"
				and p:GetAttribute("PowerReady1") == nil then
				problem(`{role} {p.Name} has no power buttons during {st}`)
			end
			local tag = tags[p]
			if status == "Downed" and not (tag and (tag.look == "Downed" or tag.look == "Out")) then
				problem(`{p.Name} is down but their tag says {tag and tag.look}`)
			elseif role == "Catcher" and st == "Running" and not (tag and tag.look == "Catcher") then
				problem(`catcher {p.Name}'s tag says {tag and tag.look}`)
			end
			-- The last runner out on the field runs at the catch-up speed (Speeds.LastRunner); nobody else does.
			if st == "Running" and role == "Runner" and status == "Active" and Config.Speeds.LastRunner then
				local others = 0
				for q in bots do
					if q ~= p and q:GetAttribute("HuzzStatus") == "Active" then others += 1 end
				end
				local base = PowerService.speedOf(p.UserId, Config.Speeds.LastRunner)
				if others == 0 and h.WalkSpeed == base and not PowerService.stuck(p.UserId) then
					stats.lastBoosted = (stats.lastBoosted or 0) + 1
				elseif others > 0 and h.WalkSpeed == base and Config.Speeds.LastRunner ~= Config.Speeds.Runner
					and h.WalkSpeed ~= PowerService.speedOf(p.UserId, Config.Speeds.Runner) then
					problem(`{p.Name} runs at the last runner's speed with {others} others still out`)
				end
			end
			if PowerService.stuck(p.UserId) and h.WalkSpeed ~= 0 then
				problem(`{p.Name} is stuck in a trap but can still move`)
			end
			-- Hero or Chicken: the picked bot answers after a moment (some let the timer run out).
			if st == "Picking" and Round:GetAttribute("PickId") == p.UserId and bot.pickedRound ~= Round:GetAttribute("Round") then
				bot.pickedRound = Round:GetAttribute("Round")
				-- someone else trying to answer is ignored
				for q in bots do
					if q ~= p then remotes.Hero.OnServerEvent:Fire(q, true) end
				end
				if bot.kind ~= "afk" and rng:NextNumber() < 0.75 then
					local hero = rng:NextNumber() < 0.6
					task.delay(Config.Pick.Roulette + rng:NextNumber() * 3, function()
						remotes.Hero.OnServerEvent:Fire(p, hero)
					end)
				else
					stats.timeoutPicks += 1
				end
			end
			-- Move: runners head across (a few go and help up a downed runner nearby first).
			local target = nil
			if (st == "Running" or st == "HeroRun") and role == "Runner" and status == "Active" then
				local goal = zones[Round:GetAttribute("Goal") or "ZoneB"]
				target = goal and goal.CFrame.Position + Vector3.new(0, -4 + 3.2, (bot.seed - 0.5) * (goal.Size.Z - 20))
				-- most kids curve away from a catcher ahead of them (within 25 studs) instead of running into it
				local threat, td = nil, 25
				for q in bots do
					if q:GetAttribute("HuzzRole") == "Catcher" and q.Character then
						local d = (seen(q) - root.Position).Magnitude
						if d < td then threat, td = seen(q), d end
					end
				end
				if practice and practice.Parent then
					local d = (practice.HumanoidRootPart.Position - root.Position).Magnitude
					if d < td then threat, td = practice.HumanoidRootPart.Position, d end
				end
				if target and threat and bot.seed < 0.8 and bot.kind ~= "weak" then
					local toGoal = Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z)
					local toThreat = Vector3.new(threat.X - root.Position.X, 0, threat.Z - root.Position.Z)
					if toGoal.Magnitude > 1 and toThreat.Magnitude > 0.5 and toGoal.Unit:Dot(toThreat.Unit) > 0.3 then
						local side = Vector3.new(-toGoal.Unit.Z, 0, toGoal.Unit.X)
						if side:Dot(toThreat) > 0 then side = -side end
						target = root.Position + (toGoal.Unit + side * 1.2).Unit * 20
					end
				end
				if st == "Running" and bot.seed < 0.6 then
					for q in bots do
						local qc = q.Character
						-- (an OUT tag: second chance used, nobody can help them up)
						if q ~= p and q:GetAttribute("HuzzStatus") == "Downed" and qc and not (tags[q] and tags[q].look == "Out") then
							local feet = qc:GetAttribute("DownedFeet")
							local at = if typeof(feet) == "CFrame" then feet.Position else qc.HumanoidRootPart.Position
							if (at - root.Position).Magnitude < 30 then
								target = at
								break
							end
						end
					end
				end
			elseif (st == "Running" or st == "HeroRun") and role == "Catcher" then
				local best, bd = nil, math.huge
				for q in bots do
					if q:GetAttribute("HuzzStatus") == "Active" and q.Character then
						local d = (seen(q) - root.Position).Magnitude
						if d < bd then best, bd = q, d end
					end
				end
				if best then
					target = seen(best)
					if bot.seed > 0.5 and Config.TagMode == "Stab" then
						-- half the catcher bots only lunge (Space), never the knife: the leap covers ground, so they
						-- jump from about Speed x Time away (Gameplay/Dash moves the catcher; here the bot moves itself)
						local L = Config.Lunge
						if bd < ((L.EndSpeed or L.Speed) + (L.Speed - (L.EndSpeed or L.Speed)) / 3) * L.Time * 0.6 + L.HitRange and clock - bot.lastStab > L.Cooldown then
						bot.lastStab = clock
						stats.lunges = (stats.lunges or 0) + 1
						root.CFrame = lookAt(root.Position, Vector3.new(target.X, root.Position.Y, target.Z))
						local before = c:GetAttribute("LungeAt")
						remotes.Lunge.OnServerEvent:Fire(p)
						if c:GetAttribute("LungeAt") ~= before then
							bot.leapUntil, bot.leapDir, bot.leapSpeed = clock + L.Time, root.CFrame.LookVector, (L.EndSpeed or L.Speed) + (L.Speed - (L.EndSpeed or L.Speed)) / 3 -- (the eased push's mean speed)
						end
						end
					elseif bd < Config.Stab.Range - 1 and clock - bot.lastStab > Config.Stab.Cooldown then
						bot.lastStab = clock
						root.CFrame = lookAt(root.Position, Vector3.new(target.X, root.Position.Y, target.Z))
						remotes.Stab.OnServerEvent:Fire(p)
					end
				end
			end
			-- The huss (Space): most runner bots dash sideways, away from a catcher closing in.
			if st == "Running" and role == "Runner" and status == "Active" and bot.seed < 0.8 and bot.kind == "normal" and h.WalkSpeed > 0 then
				local threat, td = nil, 9
				for q in bots do
					if q:GetAttribute("HuzzRole") == "Catcher" and q.Character then
						local d = (q.Character.HumanoidRootPart.Position - root.Position).Magnitude
						if d < td then threat, td = q.Character.HumanoidRootPart.Position, d end
					end
				end
				if practice and practice.Parent then
					local d = (practice.HumanoidRootPart.Position - root.Position).Magnitude
					if d < td then threat, td = practice.HumanoidRootPart.Position, d end
				end
				if threat and now >= (p:GetAttribute("DashReady") or 0) then
					local look = root.CFrame.LookVector
					local right = Vector3.new(-look.Z, 0, look.X).Unit
					local away = if (threat - root.Position):Dot(right) > 0 then -right else right
					local before = c:GetAttribute("DashAt")
					remotes.Dash.OnServerEvent:Fire(p, away, now, look)
					if c:GetAttribute("DashAt") ~= before then
						stats.husses += 1
						bot.leapUntil, bot.leapDir, bot.leapSpeed = clock + Config.Dash.Time, away, (Config.Dash.EndSpeed or Config.Dash.Speed) + (Config.Dash.Speed - (Config.Dash.EndSpeed or Config.Dash.Speed)) / 3
					end
				end
			end
			-- Safe runners try to wander back into the middle now and then (owner: they must stay across).
			local goalName = Round:GetAttribute("Goal")
			local safeNow = p:GetAttribute("HuzzStatus") == "Safe" and (st == "Running" or st == "HeroRun")
			if safeNow and goalName and zones[goalName] then
				local out = MapService.keepIn(zones[goalName], root.Position)
				if out and (out - root.Position).Magnitude > 4 then
					stats.safeOutside += 1
					problem(`{p.Name} got back out of the safe zone`)
				end
				if rng:NextNumber() < 0.5 then
					target = zones.Middle.CFrame.Position
				end
			end
			if bot.kind == "afk" then
				target = nil -- (away from the keyboard: never moves)
			end
			-- Gameplay/Sprint: a walk (9) building to the top speed, about 95% after Run.Ramp (1.2 s)
			local moving = target and h.WalkSpeed > 0 and not KnockdownService.isDown(p)
			bot.runFor = if moving then (bot.runFor or 0) + dt else 0
			local speed = math.min(h.WalkSpeed, 9 + (h.WalkSpeed - 9) * (1 - math.exp(-bot.runFor / 0.4)))
			if moving and bot.leapUntil and clock < bot.leapUntil and (st == "Running" or st == "HeroRun") then
				-- mid huss or mid lunge: the move carries them
				local nextPos = root.Position + bot.leapDir * bot.leapSpeed * dt
				root.CFrame = lookAt(nextPos, nextPos + root.CFrame.LookVector)
			elseif moving then
				local d = target - root.Position
				d = Vector3.new(d.X, 0, d.Z)
				if d.Magnitude > 0.5 then
					local nextPos = root.Position + d.Unit * math.min(d.Magnitude, speed * dt)
					-- The start wall: honest bots stop at their line; "cheat" bots walk round it.
					local startName = if Round:GetAttribute("Round") then MapService.startFor(Round:GetAttribute("Round")) else nil
					if wallOn and startName == wallOn and bot.kind ~= "cheat" and role == "Runner" then
						local back = MapService.keepIn(zones[wallOn], nextPos)
						if back then nextPos = root.Position end
					end
					-- The goal's gate stops safe runners (its collision group); "cheat" bots get round it.
					local slips = bot.kind == "cheat" or p.UserId % 3 == 0 -- (a dash or a shove: some get round it)
					if safeNow and gateOn == goalName and not slips and MapService.keepIn(zones[goalName], nextPos) then
						nextPos = root.Position
					end
					root.CFrame = lookAt(nextPos, nextPos + d.Unit)
				end
			end
			-- Powers now and then.
			if st == "Running" and rng:NextNumber() < 0.04 then
				local slot = if rng:NextNumber() < 0.5 then 1 else 2
				local ready = p:GetAttribute("PowerReady" .. slot)
				if ready and ready >= 0 and ready <= now then
					remotes.Power.OnServerEvent:Fire(p, slot)
				end
			end
		end
		-- She's always somewhere sensible.
		local holder = Round:GetAttribute("HolderId") or 0
		if holder ~= 0 and (st == "Running" or st == "Countdown") then
			local found = false
			for p in bots do
				if p.UserId == holder and carried[p] then found = true end
			end
			if not found then
				local present = false
				for p in bots do if p.UserId == holder then present = true end end
				if present then problem("HolderId " .. holder .. " but nobody carries her") end
			end
		end
	end

	-- Start everything.
	for _ = 1, opts.players do
		addPlayer()
	end
	for _ = 1, opts.afk or 0 do
		addPlayer("afk")
	end
	for _ = 1, opts.weak or 0 do
		addPlayer("weak") -- (a beginner: runs straight across, never steers or husses)
	end
	if opts.cheater then
		addPlayer("cheat")
	end
	task.spawn(loadScript("ServerScriptService/HuzzServer/RoundService.server.lua"))
	task.spawn(function()
		while true do
			RunService.Heartbeat:Fire(1 / 30)
			botFrame(1 / 30)
			task.wait(1 / 30)
		end
	end)
	-- Scripted events: someone leaves mid-game, someone joins mid-game.
	if opts.leaveAt then
		task.delay(opts.leaveAt, function()
			local holder = Round:GetAttribute("HolderId") or 0
			for p in bots do
				if p.UserId == holder or holder == 0 then
					removePlayer(p)
					break
				end
			end
		end)
	end
	local joiner
	if opts.joinAt then
		task.delay(opts.joinAt, function()
			joiner = addPlayer()
			local s = stage()
			if s == "Countdown" or s == "Running" or s == "RoundOver" then
				task.delay(1, function()
					local r = joiner:GetAttribute("HuzzRole")
					if (stage() == "Running" or stage() == "Countdown") and r ~= "Lobby" then
						problem("a player who joined mid-game got role " .. tostring(r))
					end
				end)
			end
		end)
	end
	runUntil(opts.seconds)
	watchEvents()
	for _, e in errors do
		problem("SCRIPT ERROR: " .. e)
	end
	if loads ~= stats.games and loads ~= stats.games + 1 then
		problem(`maps loaded {loads} times for {stats.games} games`)
	end
	if unloads > 0 then
		problem(`the map was removed {unloads} times outside a swap (it should stay until the next vote)`)
	end
	return stats, problems, joiner
end

------------------------------------------------------------------ loop audit
-- lune run huzz-valley/tools/sim/round_sim.luau audit   (numbers for huzz-valley/docs/loop-audit.md; real map size)
local process = require("@lune/process")
if process.args[1] == "audit" then
	local SEEDS, SECONDS = tonumber(process.args[2]) or 8, 1800
	local function sum(t)
		local n = 0
		for _, v in t do n += v end
		return n
	end
	local rows, waits, stages = {}, {}, {}
	local setups = {
		{ "1 (+ bot)", { players = 1 } }, { "1 beginner (+ bot)", { players = 0, weak = 1 } }, { "2", { players = 2 } }, { "4", { players = 4 } }, { "8", { players = 8 } },
		{ "12", { players = 12 } }, { "6 + 1 AFK", { players = 5, afk = 1 } },
	}
	local STAGES = { "Voting", "Rolling", "Lineup", "Picking", "Chosen", "HeroRun", "Countdown", "Running", "RoundOver", "GameOver" }
	local KINDS = { "play", "cutscene", "heroWatch", "safe", "down", "lobby", "lateJoin" }
	for _, setup in setups do
		if process.args[3] and not setup[1]:find(process.args[3], 1, true) then
			continue
		end
		local all = { games = 0, runnerWins = 0, catcherWins = 0, botWins = 0, lastAlone = 0, heroes = 0, heroSurvived = 0, rescues = 0, rounds = 0,
			runTimeouts = 0, runTime = 0, heroTimeouts = 0, heroEarly = 0, maxRoundGames = 0, tags = 0, husses = 0, hurries = 0,
			stageTime = {}, wait = {}, lengths = {}, rpg = {} }
		local problems = 0
		for seed = 1, SEEDS do
			local o = table.clone(setup[2])
			o.seed, o.seconds, o.realField = seed * 11, SECONDS, true
			local st, pr = simulate(o)
			problems += #pr
			for k, v in all do
				if type(v) == "number" and type(st[k]) == "number" then all[k] += st[k] end
			end
			for k, v in st.stageTime do all.stageTime[k] = (all.stageTime[k] or 0) + v end
			for k, v in st.wait do all.wait[k] = (all.wait[k] or 0) + v end
			for _, v in st.gameLengths do table.insert(all.lengths, v) end
			for _, v in st.roundsPerGame do table.insert(all.rpg, v) end
		end
		local g = math.max(#all.lengths, 1)
		local won = all.runnerWins + all.catcherWins
		local pct = function(a, b) return if b > 0 then string.format("%d%%", math.floor(a / b * 100 + 0.5)) else "-" end
		table.insert(rows, string.format("| %s | %d | %.0f s | %.1f | %s | %s (bot %s) | %s | %s | %.1f | %.1f s | %s | %d | %d | %d | %d |",
			setup[1], #all.lengths, sum(all.lengths) / g, sum(all.rpg) / g, pct(all.runnerWins, won), pct(all.catcherWins, won), pct(all.botWins, won),
			pct(all.heroSurvived, all.heroes), pct(all.heroTimeouts, all.heroes), all.rescues / g, all.runTime / math.max(all.rounds, 1),
			pct(all.runTimeouts, all.rounds), all.maxRoundGames, all.hurries, all.heroEarly, problems))
		local sline = { "| " .. setup[1] }
		for _, k in STAGES do table.insert(sline, string.format("%.1f", (all.stageTime[k] or 0) / g)) end
		table.insert(stages, table.concat(sline, " | ") .. " |")
		local total = 0
		for _, k in KINDS do total += all.wait[k] or 0 end
		local wline = { "| " .. setup[1] }
		for _, k in KINDS do table.insert(wline, pct(all.wait[k] or 0, total)) end
		table.insert(waits, table.concat(wline, " | ") .. " |")
	end
	print(`Loop audit: {SEEDS} runs x {SECONDS / 60} minutes per setup, the owner's map size (lines 280 studs apart)`)
	print("")
	print("| Players | Games | Game length | Rounds/game | Runners win | Catchers win | Hero runs made | Hero runs timed out | Rescues/game | Running stage/round | Rounds hit the clock | Games hit MaxRounds | Hurry calls | Heroes who didn't go | Sim problems |")
	print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
	for _, r in rows do print(r) end
	print("")
	print("Seconds per game in each stage (Voting = the lobby between games)")
	print("")
	print("| Players | " .. table.concat(STAGES, " | ") .. " |")
	print("|---" .. string.rep("|---", #STAGES) .. "|")
	for _, r in stages do print(r) end
	print("")
	print("Share of each player's time (play = can run, chase or rescue; AFK players not counted)")
	print("")
	print("| Players | " .. table.concat(KINDS, " | ") .. " |")
	print("|---" .. string.rep("|---", #KINDS) .. "|")
	for _, r in waits do print(r) end
	process.exit(0)
end

------------------------------------------------------------------ scenarios
local failed = 0
local function report(name, stats, problems, expect)
	local powerList = {}
	for k, v in stats.powers do
		table.insert(powerList, k .. "=" .. v)
	end
	table.sort(powerList)
	print(string.format("%-34s games %d (runners %d, catchers %d), stabs %d, tags %d, rescues %d, picks %d (timed out %d), hero runs %d (made it %d), husses %d, lunges %d, powers: %s",
		name, stats.games, stats.runnerWins, stats.catcherWins, stats.stabs, stats.tags, stats.rescues, stats.picks, stats.timeoutPicks, stats.heroes, stats.heroSurvived, stats.husses, stats.lunges or 0, table.concat(powerList, " ")))
	for _, check in expect or {} do
		if not check[2](stats) then
			table.insert(problems, "expected: " .. check[1])
		end
	end
	for _, p in problems do
		print("   PROBLEM " .. p)
	end
	failed += #problems
end

local s, p = simulate({ players = 4, seconds = 1200, seed = 1 })
report("4 players, 20 minutes", s, p, {
	{ "several games finished", function(x) return x.wins >= 3 end },
	{ "stabs tag runners", function(x) return x.tags >= 5 end },
	{ "all four powers used", function(x) return x.powers.HeartShield and x.powers.RizzRush and x.powers.LoveTrap and x.powers.CharmWave end },
	{ "every round has a pick", function(x) return x.picks >= 6 end },
	{ "Hero runs happen and some make it", function(x) return x.heroes >= 2 and x.heroSurvived >= 1 end },
	{ "catchers win some", function(x) return x.catcherWins >= 1 end },
})
s, p = simulate({ players = 6, seconds = 1500, seed = 7, config = function(c) c.Stab.Range = 9 end })
report("6 players, 25 minutes", s, p, {
	{ "games finish", function(x) return x.wins >= 3 end },
	{ "the last runner is called out and runs faster", function(x) return x.lastAlone >= 1 and (x.lastBoosted or 0) > 0 end },
	{ "a shield blocks a stab", function(x) return x.blocks >= 1 end },
	{ "runners rescue each other", function(x) return x.rescues >= 3 end },
})
s, p = simulate({ players = 2, seconds = 400, seed = 3 })
report("2 players", s, p, { { "games finish", function(x) return x.wins >= 2 end }, { "runners win some", function(x) return x.runnerWins >= 1 end } })
s, p = simulate({ players = 1, seconds = 900, seed = 4, studio = true })
report("1 player (Studio Play, Practice Bot)", s, p, {
	{ "solo games finish", function(x) return x.wins >= 2 end },
	{ "the Practice Bot chases and catches", function(x) return (x.botMoves or 0) > 0 and (x.botTags or 0) >= 1 end },
	{ "only the bot wins when the solo runner is caught", function(x) return x.catcherWins == (x.botWins or 0) end },
	{ "the Practice Bot changes speed after a game", function(x)
		local n = 0
		for _ in x.botSpeeds or {} do n += 1 end
		return n >= 2
	end },
})
print(string.format("   (Practice Bot: %d catches, %d wins, solo runner %d wins)", s.botTags or 0, s.botWins or 0, s.runnerWins))
s, p = simulate({ players = 4, seconds = 300, seed = 9 })
report("4 players: no Practice Bot", s, p, { { "the bot stays out of games with a catcher", function(x) return (x.botMoves or 0) == 0 end } })
s, p = simulate({ players = 4, cheater = true, seconds = 300, seed = 5 })
report("a runner walks round the start wall", s, p, { { "games finish", function(x) return x.wins >= 1 end } })
s, p = simulate({ players = 5, seconds = 500, seed = 6, leaveAt = 60, joinAt = 50 })
report("holder leaves, someone joins mid-game", s, p, { { "games still finish", function(x) return x.wins >= 2 end } })
s, p = simulate({ players = 4, afk = 1, seconds = 600, seed = 2 })
report("an AFK runner (never moves)", s, p, {
	{ "games finish", function(x) return x.wins >= 2 end },
	{ "the clock drops when only the AFK runner is left (Hurry)", function(x) return x.hurries >= 1 end },
	-- (a catcher hovering by the start buys 10 s, so a round where the AFK runner is left late can still run out)
	{ "rounds rarely run the whole clock", function(x) return x.runTimeouts <= 2 end },
	{ "Hero runs rarely run out of time: an AFK Hero loses it early", function(x) return x.heroTimeouts <= 1 end },
})
print(string.format("   (hurries %d, AFK Heroes cut short %d, last runner called %d, boosted frames %d)", s.hurries, s.heroEarly, s.lastAlone, s.lastBoosted or 0))
s, p = simulate({ players = 4, seconds = 600, seed = 8, config = function(c) c.TagMode = "Touch" end })
report("Touch mode (no stabbing)", s, p, { { "touch tags", function(x) return x.tags >= 3 and x.stabs == 0 end } })

print(if failed == 0 then "simulation ok" else failed .. " problems")
if failed > 0 then
	error("simulation found problems")
end
