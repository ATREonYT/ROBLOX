--!nonstrict
-- New Game Kit: a small fake Roblox for Lune, so the kit's server code and specs
-- run offline (no Studio). It covers only what the kit uses. A clean run here does
-- NOT prove Studio works: always do the Studio smoke test in the README too.
--
-- Usage (see tools/test.luau and tools/sim.luau):
--   local Mock = require("./RobloxMock")
--   local world = Mock.newWorld({ studio = false, jobId = "A", stores = sharedStores })
--   world.mount("default.project.json")       -- builds the tree from the Rojo project
--   world.require(world.game.ServerScriptService.Main)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local task = require("@lune/task")

local Mock = {}

-- Signals -------------------------------------------------------------------
local function newSignal()
	local signal = { _handlers = {} }
	function signal:Connect(fn)
		local conn = { Connected = true }
		local entry = { fn = fn, conn = conn }
		table.insert(self._handlers, entry)
		function conn.Disconnect()
			conn.Connected = false
			local i = table.find(self._handlers, entry)
			if i then
				table.remove(self._handlers, i)
			end
		end
		return setmetatable(conn, { __index = { Disconnect = conn.Disconnect } })
	end
	function signal:Once(fn)
		local conn
		conn = self:Connect(function(...)
			conn:Disconnect()
			fn(...)
		end)
		return conn
	end
	function signal:Wait()
		local thread = coroutine.running()
		self:Once(function(...)
			task.spawn(thread, ...)
		end)
		return coroutine.yield()
	end
	function signal:Fire(...)
		for _, entry in table.clone(self._handlers) do
			if entry.conn.Connected then
				task.spawn(entry.fn, ...)
			end
		end
	end
	return signal
end
Mock.newSignal = newSignal

-- Enums ---------------------------------------------------------------------
local enumMeta = { __tostring = function(e)
	return `Enum.{e.EnumType}.{e.Name}`
end }
local function enumItem(enumType, name, value)
	return setmetatable({ EnumType = enumType, Name = name, Value = value, __enum = true }, enumMeta)
end
local Enum = {}
for enumType, names in
	{
		ProductPurchaseDecision = { "NotProcessedYet", "PurchaseGranted" },
		DataStoreRequestType = { "GetAsync", "SetIncrementAsync", "UpdateAsync", "GetSortedAsync", "SetIncrementSortedAsync", "OnUpdate" },
		InfoType = { "Product", "GamePass", "Asset" },
	}
do
	Enum[enumType] = {}
	for i, name in names do
		Enum[enumType][name] = enumItem(enumType, name, i - 1)
	end
end
Mock.Enum = Enum

-- Datatypes -----------------------------------------------------------------
local Vector3 = {}
local vectors = setmetatable({}, { __mode = "k" })
function Vector3.new(x, y, z)
	local v = { X = x or 0, Y = y or 0, Z = z or 0 }
	v.Magnitude = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	local proxy = newproxy(true)
	local mt = getmetatable(proxy)
	mt.__index = function(_, k)
		local value = v[k]
		if value == nil then
			error(`{k} is not a valid member of Vector3`, 2)
		end
		return value
	end
	mt.__tostring = function()
		return `{v.X}, {v.Y}, {v.Z}`
	end
	vectors[proxy] = true
	return proxy
end
Vector3.zero = Vector3.new(0, 0, 0)

local Random = {}
function Random.new(seed)
	local rng = { _seed = seed }
	function rng:NextNumber(a, b)
		a = a or 0
		b = b or 1
		return a + math.random() * (b - a)
	end
	function rng:NextInteger(a, b)
		return math.random(a, b)
	end
	return rng
end

local function mockTypeof(v)
	if Mock.isInstance(v) then
		return "Instance"
	elseif vectors[v] then
		return "Vector3"
	elseif type(v) == "table" and rawget(v, "__enum") then
		return "EnumItem"
	end
	return typeof(v)
end
Mock.typeof = mockTypeof

-- Deep copy that refuses what a DataStore refuses -------------------------
local function storeCopy(v, path)
	local t = mockTypeof(v)
	if t == "table" then
		local out = {}
		for k, x in v do
			if type(k) ~= "string" and type(k) ~= "number" then
				error(`DataStore: key of type {type(k)} at {path}`)
			end
			out[k] = storeCopy(x, path .. "." .. tostring(k))
		end
		return out
	elseif t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then
			error(`DataStore: NaN or infinity at {path}`)
		end
		return v
	elseif t == "string" or t == "boolean" or t == "nil" then
		return v
	end
	error(`DataStore: cannot store a {t} at {path}`)
end
Mock.storeCopy = storeCopy

-- Instances -----------------------------------------------------------------
local Instance = {}
local NILABLE = { Character = true, PrimaryPart = true, Adornee = true, Value = true }
local instMethods = {}
local CLASS_PARENTS = {
	ModuleScript = { "LuaSourceContainer" },
	Script = { "LuaSourceContainer" },
	LocalScript = { "LuaSourceContainer" },
	IntValue = { "ValueBase" },
	NumberValue = { "ValueBase" },
	StringValue = { "ValueBase" },
}

local states = setmetatable({}, { __mode = "k" })
function Mock.isInstance(v)
	return states[v] ~= nil
end

local function newInstance(className, name)
	local self = {
		_props = { ClassName = className, Name = name or className },
		_children = {},
		_attrs = {},
		_attrSignals = {},
		_propSignals = {},
		_parent = nil,
	}
	self._props.ChildAdded = newSignal()
	self._props.Destroying = newSignal()
	self._props.AttributeChanged = newSignal()
	if className == "RemoteEvent" or className == "UnreliableRemoteEvent" then
		self._props.OnServerEvent = newSignal()
		self._props.OnClientEvent = newSignal()
		self._sent = {}
	elseif className == "BindableEvent" then
		self._props.Event = newSignal()
	end
	local proxy = newproxy(true)
	local mt = getmetatable(proxy)
	mt.__index = Instance.__index
	mt.__newindex = Instance.__newindex
	mt.__tostring = Instance.__tostring
	states[proxy] = self
	return proxy
end

Instance.__index = function(proxy, key)
	local self = states[proxy]
	if string.sub(key, 1, 1) == "_" then
		return self[key]
	end
	if key == "Parent" then
		return self._parent
	end
	local props = self._props
	local v = props[key]
	if v ~= nil then
		return v
	end
	if NILABLE[key] then
		return nil
	end
	local m = instMethods[key]
	if m then
		return m
	end
	for _, child in self._children do
		if child._props.Name == key then
			return child
		end
	end
	error(`{key} is not a valid member of {props.ClassName} "{props.Name}"`, 2)
end
Instance.__newindex = function(proxy, key, value)
	local self = states[proxy]
	if string.sub(key, 1, 1) == "_" then
		self[key] = value
		return
	end
	if key == "Parent" then
		if self._destroyed then
			error(`The Parent property of {self._props.Name} is locked`, 2)
		end
		local old = self._parent
		if old then
			local i = table.find(old._children, proxy)
			if i then
				table.remove(old._children, i)
			end
		end
		self._parent = value
		if value then
			table.insert(value._children, proxy)
			value._props.ChildAdded:Fire(proxy)
		end
		return
	end
	self._props[key] = value
	local sig = self._propSignals[key]
	if sig then
		sig:Fire()
	end
end
Instance.__tostring = function(proxy)
	return states[proxy]._props.Name
end

function instMethods.GetChildren(self)
	return table.clone(self._children)
end
function instMethods.GetDescendants(self)
	local out = {}
	local function walk(node)
		for _, c in node._children do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end
function instMethods.FindFirstChild(self, name)
	for _, c in self._children do
		if c._props.Name == name then
			return c
		end
	end
	return nil
end
function instMethods.WaitForChild(self, name)
	local c = instMethods.FindFirstChild(self, name)
	if not c then
		error(`WaitForChild: {self._props.Name} has no child "{name}" (the mock never waits)`, 2)
	end
	return c
end
function instMethods.FindFirstChildOfClass(self, className)
	for _, c in self._children do
		if c._props.ClassName == className then
			return c
		end
	end
	return nil
end
function instMethods.IsA(self, className)
	local cls = self._props.ClassName
	if cls == className or className == "Instance" then
		return true
	end
	for _, p in CLASS_PARENTS[cls] or {} do
		if p == className then
			return true
		end
	end
	return false
end
function instMethods.IsDescendantOf(self, ancestor)
	local p = self._parent
	while p do
		if p == ancestor then
			return true
		end
		p = p._parent
	end
	return false
end
function instMethods.GetAttribute(self, name)
	return self._attrs[name]
end
function instMethods.GetAttributes(self)
	return table.clone(self._attrs)
end
function instMethods.SetAttribute(self, name, value)
	local t = mockTypeof(value)
	if t == "table" or t == "function" then
		error(`SetAttribute: {t} is not a valid attribute type`, 2)
	end
	self._attrs[name] = value
	local sig = self._attrSignals[name]
	if sig then
		sig:Fire()
	end
	self._props.AttributeChanged:Fire(name)
end
function instMethods.GetAttributeChangedSignal(self, name)
	self._attrSignals[name] = self._attrSignals[name] or newSignal()
	return self._attrSignals[name]
end
function instMethods.GetPropertyChangedSignal(self, name)
	self._propSignals[name] = self._propSignals[name] or newSignal()
	return self._propSignals[name]
end
function instMethods.Destroy(self)
	self._props.Destroying:Fire()
	self.Parent = nil
	self._destroyed = true
	for _, c in table.clone(self._children) do
		instMethods.Destroy(c)
	end
end
function instMethods.ClearAllChildren(self)
	for _, c in table.clone(self._children) do
		instMethods.Destroy(c)
	end
end
function instMethods.GetFullName(self)
	local parts = {}
	local node = self
	while node and node._props.ClassName ~= "DataModel" do
		table.insert(parts, 1, node._props.Name)
		node = node._parent
	end
	return table.concat(parts, ".")
end
-- Remotes: the server side records what it sends so tests can read it.
function instMethods.FireClient(self, player, ...)
	table.insert(self._sent, { to = player, args = table.pack(...) })
end
function instMethods.FireAllClients(self, ...)
	table.insert(self._sent, { to = "all", args = table.pack(...) })
end
function instMethods.Fire(self, ...)
	self._props.Event:Fire(...)
end

-- The world: one fake server -------------------------------------------------
function Mock.newStores()
	return { data = {}, ordered = {}, budget = 100, failNext = 0, writes = 0 }
end

function Mock.newWorld(opts)
	opts = opts or {}
	local world = { clock = { offset = 0 }, log = {}, kicks = {} }
	local stores = opts.stores or Mock.newStores()
	world.stores = stores

	local fakeOs = table.clone(os)
	function fakeOs.time(t)
		if t then
			return os.time(t)
		end
		return os.time() + math.floor(world.clock.offset)
	end
	function fakeOs.clock()
		return os.clock() + world.clock.offset
	end
	world.os = fakeOs

	local game = newInstance("DataModel", "Game")
	game._props.JobId = opts.jobId or "job-1"
	game._props.PlaceId = opts.placeId or 1
	game._props.GameId = 1
	world.game = game
	world.closeHandlers = {}

	local function service(name, props)
		local s = newInstance(name, name)
		for k, v in props or {} do
			s._props[k] = v
		end
		s.Parent = game
		return s
	end

	-- Players
	local Players = service("Players", { PlayerAdded = newSignal(), PlayerRemoving = newSignal() })
	Players._props.GetPlayers = function(self)
		return table.clone(self._children)
	end
	Players._props.GetPlayerByUserId = function(self, userId)
		for _, p in self._children do
			if p._props.UserId == userId then
				return p
			end
		end
		return nil
	end
	function world.addPlayer(userId, name)
		local p = newInstance("Player", name or `Player{userId}`)
		p._props.UserId = userId
		p._props.DisplayName = p._props.Name
		p._props.CharacterAdded = newSignal()
		p._props.Character = nil
		p._props.Kick = function(self, message)
			table.insert(world.kicks, { userId = userId, message = message })
			world.removePlayer(self)
		end
		p.Parent = Players
		Players._props.PlayerAdded:Fire(p)
		return p
	end
	function world.removePlayer(p)
		if p._parent ~= Players then
			return
		end
		Players._props.PlayerRemoving:Fire(p)
		task.wait()
		p.Parent = nil
	end

	service("RunService", {
		IsStudio = function()
			return opts.studio == true
		end,
		IsServer = function()
			return true
		end,
		IsClient = function()
			return false
		end,
		Heartbeat = newSignal(),
		Stepped = newSignal(),
	})

	local guid = 0
	service("HttpService", {
		GenerateGUID = function(_, braces)
			guid += 1
			local s = string.format("%08x-0000-4000-8000-%012x", math.random(0, 0x7fffffff), guid)
			return if braces == false then s else "{" .. s .. "}"
		end,
		JSONEncode = function(_, v)
			return require("@lune/serde").encode("json", v)
		end,
		JSONDecode = function(_, v)
			return require("@lune/serde").decode("json", v)
		end,
	})

	-- DataStores: `stores` is shared between worlds to fake two servers.
	local function maybeFail(op)
		if stores.failNext > 0 then
			stores.failNext -= 1
			error(`502: mock {op} failure`)
		end
	end
	local function keyInfo(entry)
		return {
			Version = tostring(entry and entry.version or 0),
			GetMetadata = function()
				return entry and entry.metadata or {}
			end,
			GetUserIds = function()
				return entry and entry.userIds or {}
			end,
		}
	end
	local function getStore(fullName)
		stores.data[fullName] = stores.data[fullName] or {}
		local data = stores.data[fullName]
		local store = { Name = fullName }
		function store:GetAsync(key)
			maybeFail("GetAsync")
			local e = data[key]
			return if e then storeCopy(e.value, key) else nil, keyInfo(e)
		end
		function store:SetAsync(key, value, userIds, options)
			maybeFail("SetAsync")
			local e = data[key] or { version = 0 }
			e.value = storeCopy(value, key)
			e.version += 1
			e.userIds = userIds
			data[key] = e
			stores.writes += 1
			return tostring(e.version)
		end
		function store:UpdateAsync(key, fn)
			maybeFail("UpdateAsync")
			local e = data[key]
			local current = if e then storeCopy(e.value, key) else nil
			local newValue, userIds, metadata = fn(current, if e then keyInfo(e) else nil)
			if newValue == nil then
				return nil, nil -- cancelled
			end
			local copy = storeCopy(newValue, key)
			e = e or { version = 0 }
			e.value = copy
			e.version += 1
			e.userIds = userIds
			e.metadata = metadata
			data[key] = e
			stores.writes += 1
			return storeCopy(copy, key), keyInfo(e)
		end
		function store:RemoveAsync(key)
			maybeFail("RemoveAsync")
			local e = data[key]
			data[key] = nil
			return if e then e.value else nil
		end
		function store:IncrementAsync(key, delta)
			local _, _ = store:UpdateAsync(key, function(old)
				return (old or 0) + (delta or 1)
			end)
			return data[key].value
		end
		function store:GetSortedAsync(ascending, pageSize)
			local rows = {}
			for k, e in data do
				table.insert(rows, { key = k, value = e.value })
			end
			table.sort(rows, function(a, b)
				if ascending then
					return a.value < b.value
				end
				return a.value > b.value
			end)
			local page = {}
			for i = 1, math.min(pageSize or 50, #rows) do
				page[i] = rows[i]
			end
			return {
				IsFinished = true,
				GetCurrentPage = function()
					return page
				end,
				AdvanceToNextPageAsync = function() end,
			}
		end
		return store
	end
	service("DataStoreService", {
		GetDataStore = function(_, name, scope)
			return getStore(`DS:{name}:{scope or "global"}`)
		end,
		GetOrderedDataStore = function(_, name, scope)
			return getStore(`ODS:{name}:{scope or "global"}`)
		end,
		GetRequestBudgetForRequestType = function()
			return stores.budget
		end,
	})

	-- Marketplace: tests set world.passes[userId][passId] = true and read world.prompts.
	world.passes = {}
	world.prompts = {}
	world.productInfo = {}
	service("MarketplaceService", {
		PromptGamePassPurchaseFinished = newSignal(),
		PromptProductPurchaseFinished = newSignal(),
		UserOwnsGamePassAsync = function(_, userId, passId)
			return (world.passes[userId] or {})[passId] == true
		end,
		PromptProductPurchase = function(_, player, productId)
			table.insert(world.prompts, { kind = "product", userId = player.UserId, id = productId })
		end,
		PromptGamePassPurchase = function(_, player, passId)
			table.insert(world.prompts, { kind = "pass", userId = player.UserId, id = passId })
		end,
		GetProductInfoAsync = function(_, id)
			return world.productInfo[id] or { PriceInRobux = 0, Name = tostring(id) }
		end,
	})
	-- Fire a fake receipt through whatever the game assigned to ProcessReceipt.
	local purchaseCounter = 0
	function world.buyProduct(player, productId, purchaseId)
		purchaseCounter += 1
		local handler = game.MarketplaceService.ProcessReceipt
		assert(handler, "no ProcessReceipt set")
		return handler({
			PlayerId = player.UserId,
			ProductId = productId,
			PurchaseId = purchaseId or `P{purchaseCounter}`,
			CurrencySpent = 10,
			CurrencyType = "Robux",
			PlaceIdWherePurchased = 1,
		})
	end

	world.policy = { ArePaidRandomItemsRestricted = false, IsPaidItemTradingAllowed = true }
	world.policyByUser = {}
	service("PolicyService", {
		GetPolicyInfoForPlayerAsync = function(_, player)
			return table.clone(world.policyByUser[player.UserId] or world.policy)
		end,
	})
	service("UserService", {
		GetUserInfosByUserIdsAsync = function(_, ids)
			local out = {}
			for _, id in ids do
				table.insert(out, { Id = id, Username = `Player{id}`, DisplayName = `Player{id}` })
			end
			return out
		end,
	})
	service("StarterGui", {
		SetCore = function() end,
	})
	service("ReplicatedStorage")
	service("ServerStorage")
	service("ServerScriptService")
	service("StarterPlayer")
	service("Lighting")
	service("SoundService")
	service("TweenService")
	local workspaceInst = service("Workspace")
	game._props.Workspace = workspaceInst

	game._props.GetService = function(self, name)
		local s = instMethods.FindFirstChild(self, name)
		if not s then
			error(`GetService: the mock has no {name}`, 2)
		end
		return s
	end
	game._props.BindToClose = function(_, fn)
		table.insert(world.closeHandlers, fn)
	end
	-- Run every BindToClose handler in parallel, like a server shutting down.
	function world.shutdown()
		local pending = #world.closeHandlers
		for _, fn in world.closeHandlers do
			task.spawn(function()
				fn()
				pending -= 1
			end)
		end
		local deadline = os.clock() + 30
		while pending > 0 and os.clock() < deadline do
			task.wait(0.05)
		end
		return pending == 0
	end

	-- Globals each script sees -------------------------------------------------
	local moduleCache = {}
	local function makeEnv(scriptInst)
		local env = {
			game = game,
			workspace = workspaceInst,
			script = scriptInst,
			Instance = {
				new = function(className, parent)
					local i = newInstance(className)
					if parent then
						i.Parent = parent
					end
					return i
				end,
			},
			Enum = Enum,
			Vector3 = Vector3,
			Random = Random,
			typeof = mockTypeof,
			task = task,
			os = fakeOs,
			tick = function()
				return fakeOs.clock()
			end,
			shared = world.shared or {},
			warn = function(...)
				local parts = {}
				for i = 1, select("#", ...) do
					parts[i] = tostring((select(i, ...)))
				end
				local line = table.concat(parts, " ")
				table.insert(world.log, line)
				if opts.verbose then
					print("[warn]", line)
				end
			end,
			print = function(...)
				if opts.verbose then
					print(...)
				end
			end,
		}
		env.require = function(target)
			if Mock.isInstance(target) then
				return world.require(target)
			end
			return require(target)
		end
		return env
	end
	world.shared = {}

	function world.require(moduleInst)
		local cached = moduleCache[moduleInst]
		if cached then
			return cached.value
		end
		local path = moduleInst._path
		assert(path, `{instMethods.GetFullName(moduleInst)} has no source file`)
		local source = fs.readFile(path)
		local chunk = luau.load(source, { debugName = path, environment = makeEnv(moduleInst) })
		local value = chunk()
		moduleCache[moduleInst] = { value = value }
		return value
	end
	-- Run a Script (not a ModuleScript) in its own thread.
	function world.run(scriptInst)
		local source = fs.readFile(scriptInst._path)
		local chunk = luau.load(source, { debugName = scriptInst._path, environment = makeEnv(scriptInst) })
		local ok, err
		local done = false
		task.spawn(function()
			ok, err = pcall(chunk)
			done = true
		end)
		return function()
			return done, ok, err
		end
	end
	-- Load a chunk with extra globals (used by the spec runner).
	function world.load(path, scriptInst, extra)
		local env = makeEnv(scriptInst)
		for k, v in extra or {} do
			env[k] = v
		end
		return luau.load(fs.readFile(path), { debugName = path, environment = env })
	end

	-- Rojo-style mounting --------------------------------------------------------
	local function classFor(fileName)
		if string.match(fileName, "%.server%.luau?$") then
			return "Script", (string.gsub(fileName, "%.server%.luau?$", ""))
		elseif string.match(fileName, "%.client%.luau?$") then
			return "LocalScript", (string.gsub(fileName, "%.client%.luau?$", ""))
		elseif string.match(fileName, "%.luau?$") then
			return "ModuleScript", (string.gsub(fileName, "%.luau?$", ""))
		end
		return nil, nil
	end
	local function mountPath(path, name, parent)
		if fs.isDir(path) then
			local folder = newInstance("Folder", name)
			folder.Parent = parent
			local entries = fs.readDir(path)
			table.sort(entries)
			for _, entry in entries do
				local full = path .. "/" .. entry
				if fs.isDir(full) then
					mountPath(full, entry, folder)
				else
					local cls, childName = classFor(entry)
					if cls then
						local s = newInstance(cls, childName)
						s._path = full
						s.Parent = folder
					end
				end
			end
			return folder
		end
		local cls = classFor(path)
		local s = newInstance(cls or "ModuleScript", name)
		s._path = path
		s.Parent = parent
		return s
	end
	local function mountNode(node, inst, root)
		for key, child in node do
			if string.sub(key, 1, 1) ~= "$" then
				local existing = instMethods.FindFirstChild(inst, key)
				if child["$path"] then
					mountPath(root .. "/" .. child["$path"], key, inst)
				else
					local target = existing or newInstance(child["$className"] or "Folder", key)
					target.Parent = inst
					mountNode(child, target, root)
				end
			end
		end
	end
	function world.mount(projectPath, root)
		local serde = require("@lune/serde")
		local project = serde.decode("json", fs.readFile(projectPath))
		mountNode(project.tree, game, root or ".")
	end

	return world
end

return Mock
