--!strict
-- The client's copy of its own save (public snapshot). Read-only on the client: changes come from the server.
--   ClientData.get() -> snapshot or nil
--   ClientData.Changed:Connect(function(new, old) ... end)
--   ClientData.waitReady() -> snapshot
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.MTL.Net)
local Signal = require(ReplicatedStorage.MTL.Signal)

local ClientData = {}
ClientData.Changed = Signal.new()

local current: any = nil

function ClientData.get(): any
	return current
end

function ClientData.waitReady(): any
	while not current do
		ClientData.Changed:Wait()
	end
	return current
end

local function set(snap: any)
	if type(snap) ~= "table" then
		return
	end
	local old = current
	current = snap
	ClientData.Changed:Fire(snap, old)
end

function ClientData.init()
	Net.get("ProfileUpdated").OnClientEvent:Connect(set)
	task.spawn(function()
		local player = Players.LocalPlayer
		while player:GetAttribute("MTL_Ready") ~= true do
			player:GetAttributeChangedSignal("MTL_Ready"):Wait()
		end
		if not current then
			local ok, snap = pcall(function()
				return Net.get("RequestSnapshot"):InvokeServer()
			end)
			if ok and not current then
				set(snap)
			end
		end
	end)
end

return ClientData
