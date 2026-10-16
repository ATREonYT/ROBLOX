--[[
	The huss (owner's call): during a round, Space (gamepad A, or the HUSS tile) dashes you the way you're
	moving: forward, back, left or right, or forward when you stand still. Jumping is off in rounds, so
	Space is free. Your own character moves at once (a short LinearVelocity on your root); the server checks
	it (RoundService, "Dash") and sets DashAt/DashDir on your character so everyone sees the dash pose
	(Shared/RunMotion), and DashReady on you for the cooldown tile (Screens/PowerBar).
]]
local Dash = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Config = require(Shared.Config.Round)

local player = Players.LocalPlayer
local lastLocal = -math.huge

-- Can I dash right now? (the server checks the same and has the last word)
function Dash.ready(): boolean
	local round = Net.get("Round") :: RemoteEvent
	local role, status = player:GetAttribute("HuzzRole"), player:GetAttribute("HuzzStatus")
	local c = player.Character
	return round:GetAttribute("Stage") == "Running" and (role == "Runner" or role == "Catcher") and status ~= "Caught"
		and c ~= nil and c:GetAttribute("DownedAt") == nil and player:GetAttribute("MenuOpen") ~= true
		and Workspace:GetServerTimeNow() >= (player:GetAttribute("DashReady") or 0)
		and os.clock() - lastLocal >= Config.Dash.Cooldown - 0.1
end

function Dash.try()
	if not Dash.ready() then return end
	local c = player.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	local root = h and h.RootPart
	if not (root and not root.Anchored) or h.WalkSpeed <= 0 then return end -- (0 = stuck in a trap or frozen)
	local move = h.MoveDirection
	local dir = if move.Magnitude > 0.1 then move else root.CFrame.LookVector
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	lastLocal = os.clock()
	local at = Workspace:GetServerTimeNow()
	c:SetAttribute("DashDir", dir) -- on this screen at once; the server sets the same for everyone
	c:SetAttribute("DashAt", at)
	Net.get("Dash"):FireServer(dir, at)

	-- The push: hold this ground speed for a moment, then let the walk take over again.
	local attachment = Instance.new("Attachment")
	attachment.Name = "HuzzDash"
	attachment.Parent = root
	local push = Instance.new("LinearVelocity")
	push.Name = "HuzzDash"
	push.Attachment0 = attachment
	push.RelativeTo = Enum.ActuatorRelativeTo.World
	push.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	push.PrimaryTangentAxis = Vector3.xAxis
	push.SecondaryTangentAxis = Vector3.zAxis
	push.PlaneVelocity = Vector2.new(dir.X, dir.Z) * Config.Dash.Speed
	push.MaxForce = 1e6
	push.Parent = root
	task.delay(Config.Dash.Time, function()
		push:Destroy()
		attachment:Destroy()
	end)
end

-- Space / A only while you're in a round (jumping is off there); the lobby keeps its jump.
function Dash.start()
	local round = Net.get("Round") :: RemoteEvent
	local bound = false
	local function update()
		local role = player:GetAttribute("HuzzRole")
		local inGame = (role == "Runner" or role == "Catcher") and round:GetAttribute("Stage") ~= "GameOver"
		if inGame and not bound then
			bound = true
			ContextActionService:BindActionAtPriority("HuzzDash", function(_, state)
				if state == Enum.UserInputState.Begin then Dash.try() end
				return Enum.ContextActionResult.Sink
			end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
		elseif not inGame and bound then
			bound = false
			ContextActionService:UnbindAction("HuzzDash")
		end
	end
	player:GetAttributeChangedSignal("HuzzRole"):Connect(update)
	round:GetAttributeChangedSignal("Stage"):Connect(update)
	update()
end

return Dash
