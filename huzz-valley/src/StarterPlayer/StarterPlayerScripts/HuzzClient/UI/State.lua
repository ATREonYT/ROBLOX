-- The client's copy of the player's saved state (coins, gems, passes, cosmetics, settings), kept up to date by the
-- server. Screens read it and listen with State.changed(fn). Settings changes apply here at once and are saved by
-- the server; a refused change is put back.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Settings = require(Shared.Config.Settings)
local Net = require(Shared.Net)

local State = {}

State.data = {
	Coins = 0, Aura = 0, Wear = {}, Pity = {}, Passes = {}, Cosmetics = {}, Settings = table.clone(Settings.Defaults), Loaded = false,
	Characters = {}, Equipped = "", FavChars = {}, Dances = {}, FavDances = {}, XP = 0, Claimed = {}, Stats = {}, QuestsClaimed = {},
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

-- A number the HUD shows, which a screen may hold at its old value for a moment (the crate opening holds Coins
-- until its prize shows, so the coin pill doesn't give the prize away while the reel still spins).
local held: { [string]: number } = {}
function State.hold(key: string)
	if held[key] == nil then held[key] = State.data[key] or 0 end
end
function State.release(key: string)
	if held[key] == nil then return end
	held[key] = nil
	emit()
end
function State.shown(key: string): number
	local h = held[key]
	if h ~= nil then return h end
	return State.data[key] or 0
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

-- Asks the server to do something (equip, favourite, claim). Returns ok, message. The new state arrives by itself.
function State.action(verb: string, ...: any): (boolean, string?)
	local ok, result, why = pcall(function(...) return (Net.get("Action") :: RemoteFunction):InvokeServer(verb, ...) end, ...)
	if not ok then return false, "Couldn't reach the server." end
	return result == true, why
end

function State.start()
	(Net.get("State") :: RemoteEvent).OnClientEvent:Connect(State.apply)
	task.spawn(function()
		local ok, snap = pcall(function() return (Net.get("GetState") :: RemoteFunction):InvokeServer() end)
		if ok then State.apply(snap) end
	end)
end

return State
