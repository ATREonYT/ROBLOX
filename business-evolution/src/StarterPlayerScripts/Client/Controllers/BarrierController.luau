--!strict
-- Stage barriers. The server keeps every barrier non-colliding and gates the
-- REWARDS, so all this does is make an uncleared barrier solid for the local
-- player — the "you shall not pass until you beat the enemies" feel.
--
-- Walking through one by cheating gains nothing: Wins are awarded server-side
-- and only for stages the server agrees you have cleared.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local Trove = require(ReplicatedStorage.Packages.Trove)

local stageStateRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("StageState") :: RemoteEvent

local BarrierController = {}

local trove = Trove.new()
local cleared: { [number]: boolean } = {}

-- Barriers live at the east end of each stage folder, named by the builder.
local function barrierFor(stage: Stages.Stage): BasePart?
	local world = Workspace:FindFirstChild("BusinessEvolutionWorld")
	local folder = if world then world:FindFirstChild(stage.Id) else nil
	if not folder then
		return nil
	end
	local model = folder:FindFirstChild("StageBarrier")
	local blocker = if model then model:FindFirstChild("Blocker") else nil
	return if blocker and blocker:IsA("BasePart") then blocker else nil
end

local function refresh()
	for _, stage in Stages.List do
		if stage.Number == 0 then
			continue
		end
		local blocker = barrierFor(stage)
		if not blocker then
			continue
		end
		local open = cleared[stage.Number] == true
		-- CanCollide set on the client only affects this player's own physics,
		-- which is exactly the per-player gate we want.
		blocker.CanCollide = not open
		blocker.Transparency = if open then 0.9 else 0.5
		blocker.Color = if open then Color3.fromRGB(96, 220, 120) else Color3.fromRGB(240, 70, 70)
	end
end

function BarrierController:Init()
	trove:Connect(stageStateRemote.OnClientEvent, function(payload: any)
		if type(payload) ~= "table" or payload.Cleared == nil then
			return
		end
		table.clear(cleared)
		for _, stageNumber in payload.Cleared do
			cleared[stageNumber] = true
		end
		refresh()
	end)
end

function BarrierController:Start()
	-- The world may still be replicating when this starts, so re-apply for a
	-- few seconds rather than assuming the barriers already exist.
	trove:Add(task.spawn(function()
		for _ = 1, 10 do
			refresh()
			task.wait(1)
		end
	end))
	trove:Connect(Players.LocalPlayer.CharacterAdded, function()
		task.defer(refresh)
	end)
end

return BarrierController
