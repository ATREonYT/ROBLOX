--[[
	State  (ModuleScript, child of GameClient)
	Latest data from the server + a Changed signal, and the Request helper.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local State = {
	Data = nil, -- saved data (Power, Cash, Gems, Pets, ...)
	Passes = {},
	Playtime = 0,
	PlaytimeClaimed = {},
	ServerTimeOffset = 0,
	AutoLaunch = false,
	Leaderboards = {},
	Training = nil, -- station id while training
}

local changed = Instance.new("BindableEvent")
State.Changed = changed.Event

local receivedAt = os.clock()

Remotes.Sync.OnClientEvent:Connect(function(snap)
	State.Data = snap.Data
	State.Passes = snap.Passes
	State.Playtime = snap.Playtime
	State.PlaytimeClaimed = snap.PlaytimeClaimed
	State.ServerTimeOffset = snap.ServerTime - os.time()
	State.AutoLaunch = snap.AutoLaunch
	receivedAt = os.clock()
	changed:Fire()
end)

Remotes.Leaderboards.OnClientEvent:Connect(function(boards)
	State.Leaderboards = boards
	changed:Fire("Leaderboards")
end)

function State.ServerTime()
	return os.time() + State.ServerTimeOffset
end

-- Session playtime in seconds, ticking locally between syncs
function State.CurrentPlaytime()
	return State.Playtime + (os.clock() - receivedAt)
end

function State.Request(action, ...)
	local ok, result, message = pcall(Remotes.Request.InvokeServer, Remotes.Request, action, ...)
	if not ok then
		return false
	end
	return result, message
end

function State.WaitForData()
	while not State.Data do
		State.Changed:Wait()
	end
	return State.Data
end

return State
