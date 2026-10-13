-- The client's copy of the player's saved state (coins, gems, passes, cosmetics, settings), kept up to date by the
-- server. Screens read it and listen with State.changed(fn). Settings changes apply here at once and are saved by
-- the server; a refused change is put back.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Settings = require(Shared.Config.Settings)
local Net = require(Shared.Net)

local State = {}

State.data = {
	Coins = 0, Gems = 0, Passes = {}, Cosmetics = {}, Settings = table.clone(Settings.Defaults), Loaded = false,
}

local listeners: { (any) -> () } = {}
function State.changed(fn: (any) -> ()): () -> ()
	table.insert(listeners, fn)
	return function()
		local i = table.find(listeners, fn)
		if i then table.remove(listeners, i) end
	end
end

local function emit()
	for _, fn in table.clone(listeners) do task.spawn(fn, State.data) end
end

function State.apply(snapshot: any)
	if type(snapshot) ~= "table" then return end
	for k, v in snapshot do State.data[k] = v end
	State.data.Loaded = true
	emit()
end

function State.owns(key: string): boolean
	return State.data.Passes[key] == true or State.data.Cosmetics[key] == true
end

function State.setting(key: string): any
	local v = State.data.Settings[key]
	if v == nil then return Settings.Defaults[key] end
	return v
end

-- Changes a setting now; returns false and a message if the server refuses it (the old value comes back).
function State.setSetting(key: string, value: any): (boolean, string?)
	local old = State.data.Settings[key]
	State.data.Settings[key] = value
	emit()
	local ok, why = (Net.get("SetSetting") :: RemoteFunction):InvokeServer(key, value)
	if not ok then
		State.data.Settings[key] = old
		emit()
	end
	return ok, why
end

function State.start()
	(Net.get("State") :: RemoteEvent).OnClientEvent:Connect(State.apply)
	task.spawn(function()
		local ok, snap = pcall(function() return (Net.get("GetState") :: RemoteFunction):InvokeServer() end)
		if ok then State.apply(snap) end
	end)
end

return State
