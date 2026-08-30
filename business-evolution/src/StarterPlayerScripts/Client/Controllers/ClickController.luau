--!strict
-- Turns raw clicks/taps into RequestClick / RequestOutwork. The click sound
-- plays locally on the same frame; the popup and the actual income arrive
-- later via ClickResult, because the server owns all the math (§14).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))
local Balance = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Balance")
)
local StateController = require(script.Parent:WaitForChild("StateController"))
local SoundController = require(script.Parent:WaitForChild("SoundController"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestClick = remotes:WaitForChild("RequestClick") :: RemoteEvent
local requestOutwork = remotes:WaitForChild("RequestOutwork") :: RemoteEvent

-- Far enough to reach any rival from any camera zoom inside our rooms.
local RAY_DISTANCE_STUDS = 500

local ClickController = {}

local trove = Trove.new()
-- Until the first snapshot lands, use the config default so early clicks are
-- paced correctly instead of being free-fire.
local clickCooldown = Balance.BaseClickCooldown
local lastClickAt = 0

-- Rival bodies are client-built by RivalRenderer, which tags each model
-- "RivalModel" and stores its id in a "RivalId" attribute. A raycast hits a
-- limb part, so walk up the ancestors to find the tagged model.
local function rivalIdFromPart(part: BasePart): string?
	local node: Instance? = part
	while node and node ~= workspace do
		if CollectionService:HasTag(node, "RivalModel") then
			local id = node:GetAttribute("RivalId")
			return if typeof(id) == "string" then id else nil
		end
		node = node.Parent
	end
	return nil
end

local function handleClick(screenX: number, screenY: number)
	local now = os.clock()
	if now - lastClickAt < clickCooldown then
		return -- local pacing only; the server's token bucket is the real cap
	end
	lastClickAt = now

	-- Feedback must be same-frame: waiting on the server round trip makes
	-- clicking feel like typing over remote desktop.
	SoundController.play("Click")

	local camera = workspace.CurrentCamera
	if camera then
		local ray = camera:ViewportPointToRay(screenX, screenY)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		-- Exclude your own character or zoomed-in players would only ever
		-- click the back of their own head.
		local character = Players.LocalPlayer.Character
		params.FilterDescendantsInstances = if character then { character } else {}
		local hit = workspace:Raycast(ray.Origin, ray.Direction * RAY_DISTANCE_STUDS, params)
		if hit then
			local rivalId = rivalIdFromPart(hit.Instance)
			if rivalId then
				-- Server re-validates aliveness and reach; we just aim.
				requestOutwork:FireServer(rivalId)
				return
			end
		end
	end
	requestClick:FireServer()
end

function ClickController:Init() end

function ClickController:Start()
	-- Keep the cooldown in lockstep with the server (Coffee gear shortens it).
	task.spawn(function()
		clickCooldown = StateController.await().ClickCooldown
	end)
	-- Cast: Trove's SignalLike annotation doesn't structurally match the
	-- generic Signal type, but the runtime shapes are identical (Connect/Once).
	trove:Connect(StateController.Changed :: any, function(state: StateController.ClientState)
		clickCooldown = state.ClickCooldown
	end)

	trove:Connect(UserInputService.InputBegan, function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return -- the press landed on a GUI; the UI owns it
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			handleClick(input.Position.X, input.Position.Y)
		end
	end)

	-- Touch goes through TouchTap, not InputBegan: on mobile every camera drag
	-- and pinch starts with a touch-down, and counting those as clicks would
	-- make the camera unusable. TouchTap only fires for a tap that ends without
	-- meaningful movement.
	trove:Connect(UserInputService.TouchTap, function(touchPositions: { any }, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		local first = touchPositions[1]
		if first then
			handleClick(first.X, first.Y)
		end
	end)
end

return ClickController
