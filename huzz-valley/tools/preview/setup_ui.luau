-- Extra engine stand-ins the Huzz Valley UI needs (loaded by harness.luau before the snippet).
-- Remote functions call straight through (client InvokeServer runs the server's OnServerInvoke with the LocalPlayer),
-- input/window signals are recordable, and scripts can be started with __runScript(inst).
local roblox = __roblox
local sig = _G.__instSignal

local invokers = {}
roblox.implementProperty("RemoteFunction", "OnServerInvoke", function(self) return invokers[self] end, function(self, fn) invokers[self] = fn end)
roblox.implementMethod("RemoteFunction", "InvokeServer", function(self, ...)
	local fn = invokers[self]
	if not fn then return nil end
	return fn(game:GetService("Players").LocalPlayer, ...)
end)
for _, ev in { "InputChanged", "WindowFocused", "WindowFocusReleased" } do
	roblox.implementProperty("UserInputService", ev, function(self) return sig(self, ev) end)
end
roblox.implementMethod("UserInputService", "GetFocusedTextBox", function() return nil end)
roblox.implementProperty("MarketplaceService", "PromptProductPurchaseFinished", function(self) return sig(self, "PromptProductPurchaseFinished") end)
roblox.implementMethod("MarketplaceService", "GetProductInfo", function() error("offline") end)
local chatCallback
roblox.implementProperty("TextChatService", "OnIncomingMessage", function() return chatCallback end, function(_, fn) chatCallback = fn end)
roblox.implementMethod("Workspace", "GetServerTimeNow", function() return os.time() end)
roblox.implementMethod("DataModel", "BindToClose", function() end)
_G.__isStudio = true
-- Server and client share one DataModel here, so both sides answer true.
roblox.implementMethod("RunService", "IsServer", function() return true end)
roblox.implementMethod("RunService", "IsClient", function() return true end)

-- ProfileStore needs Roblox's DataStore servers, so the preview swaps in a small in-memory stand-in with the same
-- API the game uses (sessions, Reconcile, Save + OnAfterSave, LastSavedData). Studio and live servers use the real one.
game.ServerScriptService.HuzzServer.Vendor.ProfileStore.Source = [==[
local function copy(t) if type(t) ~= "table" then return t end local o = {} for k, v in t do o[k] = copy(v) end return o end
local function signal()
	local fns = {}
	return { Connect = function(_, f) table.insert(fns, f); return { Disconnect = function() end } end,
		Fire = function(_, ...) for _, f in table.clone(fns) do task.spawn(f, ...) end end,
		Wait = function() local th = coroutine.running(); table.insert(fns, function(...) task.spawn(th, ...) end); return coroutine.yield() end }
end
local Store = {}
Store.__index = Store
local ProfileStore = { DataStoreState = "Access" }
function ProfileStore.New(name, template)
	local s = setmetatable({ template = template }, Store)
	s.Mock = s
	return s
end
function Store:StartSessionAsync(key)
	local active = true
	local p = { Data = copy(self.template), LastSavedData = {}, OnSessionEnd = signal(), OnAfterSave = signal() }
	function p:IsActive() return active end
	function p:AddUserId() end
	function p:Reconcile()
		for k, v in self.Data and {} or {} do end
	end
	function p:Save()
		task.defer(function() p.LastSavedData = copy(p.Data); p.OnAfterSave:Fire(p.LastSavedData) end)
	end
	function p:EndSession() if active then active = false; p.OnSessionEnd:Fire() end end
	return p
end
return ProfileStore
]==]

-- Engine properties Lune knows but has no value for.
pcall(function() game:GetService("UserInputService").GamepadEnabled = false end)
pcall(function() game:GetService("UserInputService").TouchEnabled = false end)
roblox.implementProperty("SoundService", "ChildAdded", function(self) return sig(self, "ChildAdded") end)
pcall(function()
	local cam = Instance.new("Camera")
	cam.ViewportSize = roblox.Vector2.new(1920, 1080)
	cam.Parent = workspace
	workspace.CurrentCamera = cam
end)
