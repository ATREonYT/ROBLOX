--[[
	The huss (owner's call, like Huss Valley): during a round, Space (gamepad A, or the HUSS tile) throws you
	sideways: left or right of the way you face, never forward or back (owner: "make the hussing be only left or
	right"). A / stick left = left, D / stick right = right; with no sideways input you go to the side you last
	moved or hussed toward (right at first). Jumping is off in rounds, so Space is free. Your own character moves
	at once (a short LinearVelocity on your root); the server checks it (RoundService, "Dash": sideways only) and
	sets DashAt/DashDir on your character so everyone sees it, and DashReady on you for the cooldown tile
	(Screens/PowerBar). The move itself is the owner-pack-style DashLeft / DashRight animation (tools/anim/
	extract_anims.luau) on your Animator, so it replicates; without them RunAnimator draws the scripted pose.
	CATCHERS in a round lunge instead (owner: "when they press space they jump and haul at the runner"): a low leap
	forward the way they face (Config/Round.Lunge); the server stabs any runner they reach during it.
]]
local Dash = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Config = require(Shared.Config.Round)
local Sfx = require(script.Parent.Sfx)
local Library = require(Shared.AnimationLibrary)

local FADE_OUT = 0.12 -- seconds: the move hands back to the run this long before it ends (no snap)

local tracks: { [string]: AnimationTrack } = {}
local tracksFor: Instance? = nil
local function playMove(h: Humanoid, side: number)
	local name = if side < 0 then "DashLeft" else "DashRight"
	local id = Library.id(name)
	if id == "" then return end
	if tracksFor ~= h then
		tracksFor, tracks = h, {}
	end
	local t = tracks[name]
	if not t then
		local animator = h:FindFirstChildOfClass("Animator")
		if not animator then return end
		local a = Instance.new("Animation")
		a.Name = "Huzz" .. name
		a.AnimationId = id
		local ok, made = pcall(function() return animator:LoadAnimation(a) end)
		if not (ok and made) then return end
		made.Priority = Enum.AnimationPriority.Action
		made.Looped = false
		tracks[name] = made
		t = made
	end
	for other, track in tracks do
		if other ~= name and track.IsPlaying then track:Stop(0.05) end
	end
	t:Play(0.04, 1, 1)
	local length = if t.Length > 0 then t.Length else 0.44
	task.delay(math.max(0.05, length - FADE_OUT), function()
		if t.IsPlaying then t:Stop(FADE_OUT) end
	end)
end

local player = Players.LocalPlayer
local lastLocal = -math.huge
local lastSide = 1 -- 1 = right, -1 = left: where you last moved or hussed sideways (right at first)

-- Roblox's own controls: the raw stick / WASD (x = -1 left ... 1 right), whichever way you face.
local controls = nil
task.spawn(function()
	pcall(function()
		local scripts = player and player:WaitForChild("PlayerScripts", 10)
		local module = scripts and scripts:WaitForChild("PlayerModule", 10)
		if module then
			controls = (require :: any)(module):GetControls()
		end
	end)
end)
local function sideways(root: BasePart, move: Vector3): number
	if controls then
		local ok, v = pcall(function() return controls:GetMoveVector() end)
		if ok and typeof(v) == "Vector3" and math.abs(v.X) > 0.3 then
			return v.X
		end
	end
	local right = root.CFrame.RightVector
	return Vector3.new(move.X, 0, move.Z):Dot(Vector3.new(right.X, 0, right.Z).Unit)
end

-- Which side a huss goes: A/D (stick left/right), else the side you last went.
function Dash.side(root: BasePart, move: Vector3): number
	local across = sideways(root, move)
	if math.abs(across) > 0.3 then
		return if across > 0 then 1 else -1
	end
	return lastSide
end

-- Can I dash right now? (the server checks the same and has the last word)
function Dash.ready(): boolean
	local round = Net.get("Round") :: RemoteEvent
	local role, status = player:GetAttribute("HuzzRole"), player:GetAttribute("HuzzStatus")
	local c = player.Character
	local stage = round:GetAttribute("Stage")
	local playing = role == "Runner" or role == "Catcher"
	return (not playing or stage == "Running" or stage == "HeroRun") and status ~= "Downed"
		and player:GetAttribute("HuzzFrozen") ~= true
		and c ~= nil and c:GetAttribute("DownedAt") == nil and player:GetAttribute("MenuOpen") ~= true
		and Workspace:GetServerTimeNow() >= (player:GetAttribute("DashReady") or 0)
		and os.clock() - lastLocal >= (if role == "Catcher" and playing then Config.Lunge.Cooldown else Config.Dash.Cooldown) - 0.1
end

-- The catcher's lunge: a hop and a hard push forward (the way you're running, else the way you face).
local function lunge(c: Model, h: Humanoid, root: BasePart)
	lastLocal = os.clock()
	local dir = if h.MoveDirection.Magnitude > 0.2 then h.MoveDirection else root.CFrame.LookVector
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude < 0.1 then return end
	dir = dir.Unit
	Net.get("Lunge"):FireServer()
	Sfx.play("lunge")
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(v.X, Config.Lunge.Up, v.Z) -- (the hop: jumping itself is off)
	local attachment = Instance.new("Attachment")
	attachment.Name = "HuzzLunge"
	attachment.Parent = root
	local push = Instance.new("LinearVelocity")
	push.Name = "HuzzLunge"
	push.Attachment0 = attachment
	push.RelativeTo = Enum.ActuatorRelativeTo.World
	push.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	push.PrimaryTangentAxis = Vector3.xAxis
	push.SecondaryTangentAxis = Vector3.zAxis
	push.PlaneVelocity = Vector2.new(dir.X, dir.Z) * Config.Lunge.Speed
	push.MaxForce = 1e6
	push.Parent = root
	task.delay(Config.Lunge.Time, function()
		push:Destroy()
		attachment:Destroy()
	end)
end

function Dash.try()
	if not Dash.ready() then return end
	local c = player.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	local root = h and h.RootPart
	if not (root and not root.Anchored) or h.WalkSpeed <= 0 then return end -- (0 = stuck in a trap or frozen)
	local stage = (Net.get("Round") :: RemoteEvent):GetAttribute("Stage")
	if player:GetAttribute("HuzzRole") == "Catcher" and (stage == "Running" or stage == "HeroRun") then
		lunge(c, h, root)
		return
	end
	local side = Dash.side(root, h.MoveDirection)
	local right = root.CFrame.RightVector
	local dir = Vector3.new(right.X, 0, right.Z).Unit * side
	lastSide = side
	lastLocal = os.clock()
	local at = Workspace:GetServerTimeNow()
	c:SetAttribute("DashDir", dir) -- on this screen at once; the server sets the same for everyone
	c:SetAttribute("DashAt", at)
	Net.get("Dash"):FireServer(dir, at)
	Sfx.play("dash")
	playMove(h, side)

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
	-- sideways, keeping whatever forward run you had (the huss never adds forward or back)
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	local ahead = math.clamp(root.AssemblyLinearVelocity:Dot(look), 0, h.WalkSpeed)
	local v = dir * Config.Dash.Speed + look * ahead
	push.PlaneVelocity = Vector2.new(v.X, v.Z)
	push.MaxForce = 1e6
	push.Parent = root
	task.delay(Config.Dash.Time, function()
		push:Destroy()
		attachment:Destroy()
	end)
end

-- Space / A is the huss everywhere: in a round and in the lobby (owner: "remove the jumping from the lobby, and keep
-- the huss"); jumping is off for everyone.
function Dash.start()
	local round = Net.get("Round") :: RemoteEvent
	local bound = false
	local function update()
		local inGame = true
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
	-- remember the side you last moved toward (A or D), for a huss with no sideways input
	RunService.Heartbeat:Connect(function()
		local c = player.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		local root = h and h.RootPart
		if root and h.MoveDirection.Magnitude > 0.1 then
			local across = sideways(root, h.MoveDirection)
			if math.abs(across) > 0.3 then
				lastSide = if across > 0 then 1 else -1
			end
		end
	end)
	player:GetAttributeChangedSignal("HuzzRole"):Connect(update)
	round:GetAttributeChangedSignal("Stage"):Connect(update)
	update()
end

return Dash
