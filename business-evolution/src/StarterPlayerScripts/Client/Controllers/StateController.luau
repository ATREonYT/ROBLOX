--!strict
-- Caches the latest full ClientState snapshot from the server. Every other
-- controller reads state from here and only here, so there is exactly one
-- source of truth on the client and nobody else touches the StateChanged remote.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))
local Signal = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Signal"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

-- The wire payload is ClientState plus the derived ClickCooldown the server
-- appends (see CONTRACTS.md, StateChanged). Declared here so every consumer
-- gets the extra field without Types.luau having to know about it.
export type ClientState = Types.ClientState & { ClickCooldown: number }

local StateController = {}

-- Fired with the fresh snapshot after the cache updates, so a handler that
-- calls .Get() inside its callback can never observe a stale value.
StateController.Changed = Signal.new() :: Signal.Signal<ClientState>

local trove = Trove.new()
local latest: ClientState? = nil

function StateController.Get(): ClientState?
	return latest
end

-- Yields until the first snapshot arrives. Controllers call this from Start
-- inside task.spawn so a slow profile load can never stall the whole client.
function StateController.await(): ClientState
	local cached = latest
	if cached then
		return cached
	end
	return StateController.Changed:Wait()
end

function StateController:Init()
	-- Connect in Init, not Start: the server pushes the first state the moment
	-- the profile loads, and a snapshot missed during startup is gone forever.
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local stateChanged = remotes:WaitForChild("StateChanged") :: RemoteEvent
	trove:Connect(stateChanged.OnClientEvent, function(state: ClientState)
		latest = state
		StateController.Changed:Fire(state)
	end)
end

function StateController:Start() end

return StateController
