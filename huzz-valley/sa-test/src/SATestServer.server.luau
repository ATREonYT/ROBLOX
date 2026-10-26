-- SATestServer: the server half of the Server Authority test place (huzz-valley/sa-test). Gives every player the
-- buttons the simulation reads, puts the push on every body at spawn, and starts the shared simulation (HussSim).
-- Report lines in Output start with [SATest].
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HussSim = require(ReplicatedStorage:WaitForChild("HussSim"))

local mode = Workspace.AuthorityMode
if mode ~= Enum.AuthorityMode.Server then
	warn("[SATest] Workspace > AuthorityMode is " .. tostring(mode) .. ": set it to Server, save, and press Play again")
end

-- players walk through each other, as in the game
local GROUP = "SAPlayers"
pcall(function()
	PhysicsService:RegisterCollisionGroup(GROUP)
	PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)
end)

local function bind(actionObj: Instance, name: string, props: { [string]: any })
	local b = Instance.new("InputBinding")
	b.Name = name
	for k, v in props do
		local ok = pcall(function() (b :: any)[k] = v end)
		if not ok then
			b:Destroy()
			return
		end
	end
	b.Parent = actionObj
end

local function buttonAction(ctx: Instance, name: string, keys: { any })
	local a = Instance.new("InputAction")
	a.Name = name
	a.Type = Enum.InputActionType.Bool
	for i, key in keys do
		bind(a, name .. i, { KeyCode = key })
	end
	a.Parent = ctx
end

local function buildInputs(player: Player)
	if player:FindFirstChild("HussContext") then return end
	local ctx = Instance.new("InputContext")
	ctx.Name = "HussContext"
	ctx.Enabled = true
	local steer = Instance.new("InputAction")
	steer.Name = "Steer"
	steer.Type = Enum.InputActionType.Direction2D
	bind(steer, "Keyboard", { Up = Enum.KeyCode.W, Down = Enum.KeyCode.S, Left = Enum.KeyCode.A, Right = Enum.KeyCode.D })
	bind(steer, "Gamepad", { KeyCode = Enum.KeyCode.Thumbstick1 })
	steer.Parent = ctx
	buttonAction(ctx, "Huss", { Enum.KeyCode.Space, Enum.KeyCode.ButtonA })
	local click = (Enum.KeyCode :: any).MouseLeftButton
	buttonAction(ctx, "Dive", { Enum.KeyCode.E, Enum.KeyCode.ButtonR2, click })
	local cam = Instance.new("InputAction")
	cam.Name = "CameraDir"
	cam.Type = Enum.InputActionType.Direction3D
	cam.Parent = ctx
	ctx.Parent = player
end

local function onCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = 0 -- Space is the huss
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then d.CollisionGroup = GROUP end
	end
	character.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then d.CollisionGroup = GROUP end
	end)
	-- the push, wired once; the simulation only switches it on and sets its speed
	local at = Instance.new("Attachment")
	at.Name = "SAPushAt"
	at.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Name = HussSim.PUSH
	lv.Attachment0 = at
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.xAxis
	lv.SecondaryTangentAxis = Vector3.zAxis
	lv.MaxForce = 1e6
	lv.Enabled = false
	lv.Parent = root
	for k, v in HussSim.START do
		root:SetAttribute(k, v)
	end
end

local function onPlayer(player: Player)
	buildInputs(player)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then task.spawn(onCharacter, player.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do onPlayer(p) end

HussSim.Initialize()
print("[SATest] server ready: AuthorityMode " .. tostring(Workspace.AuthorityMode) .. ", simulation at 60 a second")
