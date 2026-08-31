--!nonstrict
-- A headless stand-in for the slice of the Roblox API our map builders use.
-- The point is to actually EXECUTE Kit.luau and the floor modules outside
-- Studio, so runtime errors and bad geometry surface in CI instead of on a
-- player's screen. The maths here (CFrame especially) has to be real —
-- approximations would make every geometry assertion meaningless.

local M = {}

-- Roblox's task library. Scheduled work is RECORDED, not run: services start
-- `while true do task.wait() end` loops at boot, and running one here would
-- hang the harness. We are testing that startup completes, not the loops.
local scheduled = {}
local taskLib = {
	spawn = function(fn, ...) table.insert(scheduled, fn) return fn end,
	defer = function(fn, ...) table.insert(scheduled, fn) return fn end,
	delay = function(_, fn, ...) table.insert(scheduled, fn) return fn end,
	wait = function() return 0 end,
	cancel = function() end,
	synchronize = function() end,
	desynchronize = function() end,
}
M.task = taskLib
M.scheduled = scheduled

-- A minimal RBXScriptSignal: connections are recorded so a spec can fire them.
local function makeSignal()
	local handlers = {}
	return {
		Connect = function(_, fn)
			table.insert(handlers, fn)
			return { Disconnect = function() end, Connected = true }
		end,
		Once = function(_, fn)
			table.insert(handlers, fn)
			return { Disconnect = function() end, Connected = true }
		end,
		Wait = function() return nil end,
		Fire = function(_, ...)
			for _, fn in handlers do fn(...) end
		end,
		_handlers = handlers,
	}
end
M.makeSignal = makeSignal

-- ── Vector3 ────────────────────────────────────────────────────────────────
local Vector3 = {}
Vector3.__index = Vector3

local function vec(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z }, Vector3)
end

function Vector3.new(x, y, z)
	return vec(x or 0, y or 0, z or 0)
end

Vector3.__add = function(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
Vector3.__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
Vector3.__unm = function(a) return vec(-a.X, -a.Y, -a.Z) end
Vector3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
Vector3.__mul = function(a, b)
	if type(b) == "number" then return vec(a.X * b, a.Y * b, a.Z * b) end
	if type(a) == "number" then return vec(b.X * a, b.Y * a, b.Z * a) end
	return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
Vector3.__div = function(a, b)
	if type(b) == "number" then return vec(a.X / b, a.Y / b, a.Z / b) end
	return vec(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
Vector3.__tostring = function(a) return ("%.2f, %.2f, %.2f"):format(a.X, a.Y, a.Z) end
Vector3.__index = function(self, key)
	if key == "Magnitude" then
		return math.sqrt(self.X ^ 2 + self.Y ^ 2 + self.Z ^ 2)
	elseif key == "Unit" then
		local m = math.sqrt(self.X ^ 2 + self.Y ^ 2 + self.Z ^ 2)
		if m == 0 then return vec(0, 0, 0) end
		return vec(self.X / m, self.Y / m, self.Z / m)
	end
	return rawget(Vector3, key)
end
function Vector3.Dot(self, other) return self.X * other.X + self.Y * other.Y + self.Z * other.Z end
Vector3.zero = vec(0, 0, 0)
Vector3.one = vec(1, 1, 1)

-- ── Vector2 ────────────────────────────────────────────────────────────────
local Vector2 = {}
Vector2.__index = Vector2
local function vec2(x, y) return setmetatable({ X = x, Y = y }, Vector2) end
function Vector2.new(x, y) return vec2(x or 0, y or 0) end
Vector2.__add = function(a, b) return vec2(a.X + b.X, a.Y + b.Y) end
Vector2.__sub = function(a, b) return vec2(a.X - b.X, a.Y - b.Y) end
Vector2.__unm = function(a) return vec2(-a.X, -a.Y) end
Vector2.__mul = function(a, b)
	if type(b) == "number" then return vec2(a.X * b, a.Y * b) end
	if type(a) == "number" then return vec2(b.X * a, b.Y * a) end
	return vec2(a.X * b.X, a.Y * b.Y)
end
Vector2.__tostring = function(a) return ("%.2f, %.2f"):format(a.X, a.Y) end

-- ── CFrame (position + 3x3 rotation, stored row-major like Roblox) ─────────
local CFrame = {}

local function cf(x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
	return setmetatable({
		X = x, Y = y, Z = z,
		R00 = r00, R01 = r01, R02 = r02,
		R10 = r10, R11 = r11, R12 = r12,
		R20 = r20, R21 = r21, R22 = r22,
	}, CFrame)
end

CFrame.__index = function(self, key)
	if key == "Position" or key == "p" then
		return vec(self.X, self.Y, self.Z)
	elseif key == "LookVector" then
		-- Roblox looks down -Z of its own frame.
		return vec(-self.R02, -self.R12, -self.R22)
	elseif key == "RightVector" then
		return vec(self.R00, self.R10, self.R20)
	elseif key == "UpVector" then
		return vec(self.R01, self.R11, self.R21)
	end
	return rawget(CFrame, key)
end

function CFrame.new(x, y, z)
	if type(x) == "table" and x.X ~= nil and y == nil then
		return cf(x.X, x.Y, x.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	end
	return cf(x or 0, y or 0, z or 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
end

function CFrame.Angles(rx, ry, rz)
	local cx, sx = math.cos(rx), math.sin(rx)
	local cy, sy = math.cos(ry), math.sin(ry)
	local cz, sz = math.cos(rz), math.sin(rz)
	-- R = Rx * Ry * Rz, matching Roblox's CFrame.Angles order.
	return cf(
		0, 0, 0,
		cy * cz, -cy * sz, sy,
		sx * sy * cz + cx * sz, -sx * sy * sz + cx * cz, -sx * cy,
		-cx * sy * cz + sx * sz, cx * sy * sz + sx * cz, cx * cy
	)
end

CFrame.identity = CFrame.new(0, 0, 0)

CFrame.__mul = function(a, b)
	if getmetatable(b) == Vector3 then
		-- Transform a point into a's frame.
		return vec(
			a.R00 * b.X + a.R01 * b.Y + a.R02 * b.Z + a.X,
			a.R10 * b.X + a.R11 * b.Y + a.R12 * b.Z + a.Y,
			a.R20 * b.X + a.R21 * b.Y + a.R22 * b.Z + a.Z
		)
	end
	local px = a.R00 * b.X + a.R01 * b.Y + a.R02 * b.Z + a.X
	local py = a.R10 * b.X + a.R11 * b.Y + a.R12 * b.Z + a.Y
	local pz = a.R20 * b.X + a.R21 * b.Y + a.R22 * b.Z + a.Z
	return cf(
		px, py, pz,
		a.R00 * b.R00 + a.R01 * b.R10 + a.R02 * b.R20,
		a.R00 * b.R01 + a.R01 * b.R11 + a.R02 * b.R21,
		a.R00 * b.R02 + a.R01 * b.R12 + a.R02 * b.R22,
		a.R10 * b.R00 + a.R11 * b.R10 + a.R12 * b.R20,
		a.R10 * b.R01 + a.R11 * b.R11 + a.R12 * b.R21,
		a.R10 * b.R02 + a.R11 * b.R12 + a.R12 * b.R22,
		a.R20 * b.R00 + a.R21 * b.R10 + a.R22 * b.R20,
		a.R20 * b.R01 + a.R21 * b.R11 + a.R22 * b.R21,
		a.R20 * b.R02 + a.R21 * b.R12 + a.R22 * b.R22
	)
end

CFrame.__add = function(a, b) return cf(a.X + b.X, a.Y + b.Y, a.Z + b.Z, a.R00, a.R01, a.R02, a.R10, a.R11, a.R12, a.R20, a.R21, a.R22) end
CFrame.__tostring = function(a) return ("CF(%.2f, %.2f, %.2f)"):format(a.X, a.Y, a.Z) end

function CFrame.GetComponents(self)
	return self.X, self.Y, self.Z, self.R00, self.R01, self.R02, self.R10, self.R11, self.R12, self.R20, self.R21, self.R22
end

function CFrame.PointToObjectSpace(self, point)
	local dx, dy, dz = point.X - self.X, point.Y - self.Y, point.Z - self.Z
	-- Inverse of a rotation matrix is its transpose.
	return vec(
		self.R00 * dx + self.R10 * dy + self.R20 * dz,
		self.R01 * dx + self.R11 * dy + self.R21 * dz,
		self.R02 * dx + self.R12 * dy + self.R22 * dz
	)
end

function CFrame.ToWorldSpace(self, other) return self * other end
function CFrame.Lerp(self, other, alpha)
	return CFrame.new(
		self.X + (other.X - self.X) * alpha,
		self.Y + (other.Y - self.Y) * alpha,
		self.Z + (other.Z - self.Z) * alpha
	)
end

-- ── Color3 ─────────────────────────────────────────────────────────────────
local Color3 = {}
Color3.__index = Color3
local function col(r, g, b) return setmetatable({ R = r, G = g, B = b }, Color3) end
function Color3.new(r, g, b) return col(r or 0, g or 0, b or 0) end
function Color3.fromRGB(r, g, b) return col((r or 0) / 255, (g or 0) / 255, (b or 0) / 255) end
function Color3.Lerp(self, other, a)
	return col(self.R + (other.R - self.R) * a, self.G + (other.G - self.G) * a, self.B + (other.B - self.B) * a)
end
Color3.__tostring = function(c) return ("RGB(%d,%d,%d)"):format(c.R * 255, c.G * 255, c.B * 255) end

-- ── UDim / UDim2 ───────────────────────────────────────────────────────────
local UDim = {}
UDim.__index = UDim
function UDim.new(s, o) return setmetatable({ Scale = s or 0, Offset = o or 0 }, UDim) end

local UDim2 = {}
UDim2.__index = UDim2
function UDim2.new(xs, xo, ys, yo)
	return setmetatable({ X = UDim.new(xs, xo), Y = UDim.new(ys, yo) }, UDim2)
end
function UDim2.fromScale(x, y) return UDim2.new(x, 0, y, 0) end
function UDim2.fromOffset(x, y) return UDim2.new(0, x, 0, y) end

-- ── Enum (permissive: any Enum.Category.Item resolves) ─────────────────────
local enumItemMt = { __tostring = function(e) return "Enum." .. e.Category .. "." .. e.Name end }
local Enum = setmetatable({}, {
	__index = function(_, category)
		return setmetatable({}, {
			__index = function(_, name)
				return setmetatable({ Category = category, Name = name, Value = 0 }, enumItemMt)
			end,
		})
	end,
})

-- ── Instance ───────────────────────────────────────────────────────────────
local allInstances = {}

local Instance = {}
local instanceMt = {}

local function isInstance(v)
	return type(v) == "table" and getmetatable(v) == instanceMt
end

instanceMt.__index = function(self, key)
	local props = rawget(self, "_props")
	if props[key] ~= nil then return props[key] end
	-- Child lookup by name, like Roblox.
	for _, child in rawget(self, "_children") do
		if rawget(child, "_props").Name == key then return child end
	end
	local method = rawget(Instance, key)
	if method then return method end
	if key == "Position" then
		local c = props.CFrame
		return if c then c.Position else Vector3.new(0, 0, 0)
	end
	return nil
end

instanceMt.__newindex = function(self, key, value)
	local props = rawget(self, "_props")
	if key == "Parent" then
		local old = props.Parent
		if old ~= nil and isInstance(old) then
			local siblings = rawget(old, "_children")
			for i, c in siblings do
				if c == self then table.remove(siblings, i) break end
			end
		end
		props.Parent = value
		if value ~= nil and isInstance(value) then
			table.insert(rawget(value, "_children"), self)
		end
		return
	end
	if key == "Position" and props.CFrame ~= nil then
		local c = props.CFrame
		props.CFrame = cf(value.X, value.Y, value.Z, c.R00, c.R01, c.R02, c.R10, c.R11, c.R12, c.R20, c.R21, c.R22)
		return
	end
	props[key] = value
end

instanceMt.__tostring = function(self)
	return rawget(self, "_props").ClassName .. "(" .. tostring(rawget(self, "_props").Name) .. ")"
end

-- Classes our map code actually creates. Defaults mirror Roblox's.
local CLASS_DEFAULTS = {
	Part = { Anchored = false, CanCollide = true, CanQuery = true, CanTouch = true, CastShadow = true, Transparency = 0, Size = nil, Material = nil, Shape = nil },
	WedgePart = { Anchored = false, CanCollide = true, CanQuery = true, Transparency = 0 },
	MeshPart = { Anchored = false, CanCollide = true, CanQuery = true, Transparency = 0 },
	SpecialMesh = {},
	Model = { PrimaryPart = nil },
	Folder = {},
	SurfaceGui = {},
	BillboardGui = {},
	ScreenGui = {},
	Frame = {},
	TextLabel = {},
	ImageLabel = {},
	UICorner = {},
	UIStroke = {},
	UIGradient = {},
	UIListLayout = {},
	UIPadding = {},
	UIScale = {},
	UIAspectRatioConstraint = {},
	UITextSizeConstraint = {},
	UISizeConstraint = {},
	Sky = {},
	PointLight = { Enabled = true },
	SpotLight = { Enabled = true },
	SurfaceLight = { Enabled = true },
	ParticleEmitter = { Enabled = true },
	Attachment = {},
	Beam = {},
	Trail = {},
	Sound = {},
	ProximityPrompt = {},
	SpawnLocation = { Anchored = false, CanCollide = true },
	WeldConstraint = {},
	NumberValue = { Value = 0 },
	StringValue = { Value = "" },
	BoolValue = { Value = false },
	Texture = {},
	Decal = {},
	ProximityPrompt = { HoldDuration = 0, MaxActivationDistance = 10, RequiresLineOfSight = true },
	ColorCorrectionEffect = {},
	BloomEffect = {},
	ModuleScript = {},
	RemoteEvent = {},
	RemoteFunction = {},
	DataStoreOptions = {},
	DataStoreSetOptions = {},
	DataStoreIncrementOptions = {},
	Configuration = {},
	Team = {},
	Script = {},
	LocalScript = {},
	Highlight = {},
}

function Instance.new(className, parent)
	local defaults = CLASS_DEFAULTS[className]
	assert(defaults ~= nil, "roblox_mock: unsupported Instance class '" .. tostring(className) .. "'")
	local props = { ClassName = className, Name = className, Parent = nil }
	for k, v in defaults do props[k] = v end
	local inst = setmetatable({ _props = props, _children = {} }, instanceMt)
	if className == "Part" or className == "SpawnLocation" or className == "MeshPart" or className == "WedgePart" then
		props.Touched = makeSignal()
		props.TouchEnded = makeSignal()
	end
	if className == "RemoteEvent" then
		props.OnServerEvent = makeSignal()
		props.OnClientEvent = makeSignal()
		props.FireClient = function(_, _player, ...) end
		props.FireAllClients = function(_, ...) end
		props.FireServer = function(_, ...) end
	elseif className == "RemoteFunction" then
		props.OnServerInvoke = nil
		props.InvokeServer = function() end
	end
	table.insert(allInstances, inst)
	if parent ~= nil then inst.Parent = parent end
	return inst
end

function Instance.IsA(self, className)
	local mine = rawget(self, "_props").ClassName
	if mine == className then return true end
	-- Only the inheritance our code actually tests against.
	if className == "BasePart" then
		return mine == "Part" or mine == "WedgePart" or mine == "MeshPart" or mine == "SpawnLocation"
	end
	if className == "GuiObject" then
		return mine == "Frame" or mine == "TextLabel" or mine == "ImageLabel"
	end
	if className == "LayerCollector" then
		return mine == "SurfaceGui" or mine == "BillboardGui" or mine == "ScreenGui"
	end
	return false
end

function Instance.GetChildren(self)
	local out = {}
	for i, c in rawget(self, "_children") do out[i] = c end
	return out
end

function Instance.GetDescendants(self)
	local out = {}
	local function walk(node)
		for _, child in rawget(node, "_children") do
			table.insert(out, child)
			walk(child)
		end
	end
	walk(self)
	return out
end

function Instance.FindFirstChild(self, name, recursive)
	for _, child in rawget(self, "_children") do
		if rawget(child, "_props").Name == name then return child end
	end
	if recursive then
		for _, child in rawget(self, "_children") do
			local found = Instance.FindFirstChild(child, name, true)
			if found then return found end
		end
	end
	return nil
end

function Instance.FindFirstChildWhichIsA(self, className, recursive)
	for _, child in rawget(self, "_children") do
		if Instance.IsA(child, className) then return child end
	end
	if recursive then
		for _, child in rawget(self, "_children") do
			local found = Instance.FindFirstChildWhichIsA(child, className, true)
			if found then return found end
		end
	end
	return nil
end

function Instance.FindFirstAncestorWhichIsA(self, className)
	local node = rawget(self, "_props").Parent
	while node ~= nil and isInstance(node) do
		if Instance.IsA(node, className) then return node end
		node = rawget(node, "_props").Parent
	end
	return nil
end

function Instance.FindFirstChildOfClass(self, className)
	for _, child in rawget(self, "_children") do
		if rawget(child, "_props").ClassName == className then return child end
	end
	return nil
end

function Instance.WaitForChild(self, name)
	local found = Instance.FindFirstChild(self, name)
	assert(found ~= nil, "roblox_mock: WaitForChild would block forever for '" .. name .. "'")
	return found
end

function Instance.Destroy(self)
	self.Parent = nil
end

function Instance.Clone(self)
	local copy = Instance.new(rawget(self, "_props").ClassName)
	for k, v in rawget(self, "_props") do
		if k ~= "Parent" and k ~= "ClassName" then rawget(copy, "_props")[k] = v end
	end
	for _, child in rawget(self, "_children") do
		Instance.Clone(child).Parent = copy
	end
	return copy
end

function Instance.PivotTo(self, target) rawget(self, "_props").CFrame = target end
function Instance.GetPivot(self)
	local props = rawget(self, "_props")
	if props.CFrame then return props.CFrame end
	if props.PrimaryPart then return rawget(props.PrimaryPart, "_props").CFrame end
	return CFrame.new(0, 0, 0)
end
function Instance.SetPrimaryPartCFrame(self, target) rawget(self, "_props").CFrame = target end
-- DataStoreOptions carries this; harmless to expose on every mock instance.
function Instance.SetExperimentalFeatures() end

function Instance.GetPropertyChangedSignal()
	return { Connect = function() return { Disconnect = function() end } end }
end

-- ── Services ───────────────────────────────────────────────────────────────
local taggedInstances = {}
local CollectionService = {
	AddTag = function(_, inst, tag)
		taggedInstances[tag] = taggedInstances[tag] or {}
		table.insert(taggedInstances[tag], inst)
	end,
	GetTagged = function(_, tag)
		return taggedInstances[tag] or {}
	end,
	HasTag = function(_, inst, tag)
		for _, tagged in taggedInstances[tag] or {} do
			if tagged == inst then return true end
		end
		return false
	end,
	GetInstanceAddedSignal = function() return { Connect = function() return { Disconnect = function() end } end } end,
	GetInstanceRemovedSignal = function() return { Connect = function() return { Disconnect = function() end } end } end,
}

-- Service handles are permissive path stubs: `ReplicatedStorage.Shared.Config`
-- resolves to the same stub rather than nil. Module code walks these paths on
-- the way to a require(), and the harness has already rewritten the require
-- itself, so the walk just needs to not explode.
local pathStub = {}
pathStub.__index = function(self, key)
	if key == "Name" then return rawget(self, "_name") end
	return setmetatable({ _name = key }, pathStub)
end
pathStub.__tostring = function(self) return "PathStub(" .. tostring(rawget(self, "_name")) .. ")" end

local services = {}
-- Workspace and Lighting get real Instance handles: map code parents into them
-- and searches them, so a path stub would silently swallow the whole map.
local REAL_SERVICES = { Workspace = true, Lighting = true, ReplicatedStorage = true, ServerStorage = true, ServerScriptService = true }

-- The Remotes folder Rojo declares in the real place. Services WaitForChild
-- these at boot, so the harness has to provide them or every Net.bind fails.
local REMOTE_NAMES = { "RequestClick", "RequestOutwork", "RequestPurchaseGear", "RequestRestructure", "RequestSeverance", "RequestHireIntern", "RequestEquipIntern", "RequestTeleport", "StateChanged", "RivalState", "ClickResult", "Fx", "InternRollResult" }

local function populateReplicatedStorage(rs)
	local folder = Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = rs
	for _, remoteName in REMOTE_NAMES do
		local r = Instance.new("RemoteEvent")
		r.Name = remoteName
		r.Parent = folder
	end
end


-- Services whose signals/methods get touched during startup.
local function buildServiceStub(name)
	local stub = {
		Name = name,
		-- Every signal a service might connect at boot.
		PlayerAdded = makeSignal(),
		PlayerRemoving = makeSignal(),
		Heartbeat = makeSignal(),
		Stepped = makeSignal(),
		RenderStepped = makeSignal(),
		PromptGamePassPurchaseFinished = makeSignal(),
		PromptTriggered = makeSignal(),
		Changed = makeSignal(),
		GetPlayers = function() return {} end,
		IsStudio = function() return true end,
		IsServer = function() return true end,
		IsClient = function() return false end,
		IsRunning = function() return true end,
		GenerateGUID = function(_, wrapped) return "00000000-0000-0000-0000-000000000000" end,
		JSONEncode = function(_, v) return "{}" end,
		JSONDecode = function(_, v) return {} end,
		UserOwnsGamePassAsync = function() return false end,
		GetProductInfo = function() return {} end,
		BindToClose = function() end,
		GetDataStore = function() return nil end,
		GetOrderedDataStore = function() error("DataStores are unavailable in the harness", 0) end,
		SubscribeAsync = function() return { Disconnect = function() end } end,
		PublishAsync = function() end,
		Create = function() return { Play = function() end, Completed = makeSignal() } end,
	}
	return setmetatable(stub, {
		-- Anything else a service reaches for becomes a no-op method. Service
		-- access at boot is overwhelmingly method calls (SetExperimentalFeatures,
		-- BindToClose...), and an unmocked one must not fake a startup crash.
		__index = function(_, key)
			return function() return nil end
		end,
	})
end

local game = {
	PlaceId = 0,
	JobId = "harness",
	GetService = function(_, name)
		if name == "CollectionService" then return CollectionService end
		if services[name] == nil then
			if REAL_SERVICES[name] then
				local inst = Instance.new("Folder")
				inst.Name = name
				services[name] = inst
				if name == "ReplicatedStorage" then
					populateReplicatedStorage(inst)
				end
			else
				services[name] = buildServiceStub(name)
			end
		end
		return services[name]
	end,
}

-- Roblox's typeof(): our datatypes are tables, so the real global would just
-- say "table" and every typeof() guard in the codebase would misfire.
local function robloxTypeof(v)
	local mt = getmetatable(v)
	if mt == CFrame then return "CFrame" end
	if mt == Vector3 then return "Vector3" end
	if mt == Vector2 then return "Vector2" end
	if mt == Color3 then return "Color3" end
	if mt == UDim2 then return "UDim2" end
	if mt == UDim then return "UDim" end
	if mt == instanceMt then return "Instance" end
	if type(v) == "table" and rawget(v, "Category") ~= nil and rawget(v, "Name") ~= nil then
		return "EnumItem"
	end
	return type(v)
end

M.typeof = robloxTypeof
M.workspace = game:GetService("Workspace")

M.Vector2 = Vector2
M.Vector3 = Vector3
M.CFrame = CFrame
M.Color3 = Color3
M.UDim = UDim
M.UDim2 = UDim2
M.Enum = Enum
M.Instance = Instance
M.game = game
M.CollectionService = CollectionService
M.allInstances = allInstances
M.taggedInstances = taggedInstances
M.isInstance = isInstance

return M
