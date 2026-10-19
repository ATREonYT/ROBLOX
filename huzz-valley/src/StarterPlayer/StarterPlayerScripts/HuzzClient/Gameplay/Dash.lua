--[[
	The huss (owner's call, like Huss Valley): Space (gamepad A, or the HUSS tile) throws you left or right ON YOUR
	SCREEN (the camera's right), never forward or back (owner: "make the hussing be only left or right"; "it only
	goes one way"). A / stick left = left, D / stick right = right; with no sideways input you go to the side you
	last moved or hussed toward (right at first). Jumping is off, so Space is free.
	Smooth like Huss Valley (owner: "make the hussing more smooth"; docs/feel-study.md gap 7): the push eases every
	frame from Config/Round.Dash Speed to EndSpeed over Time (0.28 s, ~12 studs, front-loaded: Shared/RunMotion.pushSpeed;
	ready again after exactly 2 s, owner Oct 19: "quicker reset Huss (2 seconds)"), keeping
	whatever run you had, then the run takes over. The body is never snapped round: it eases (0.08 s) to whichever
	way along the camera's line is nearer (so at most a quarter turn, and none in shift lock), and the huss is a
	lean to that side. The pose is Shared/RunMotion's (Gameplay/RunAnimator draws it on everyone, you too), unless
	the owner publishes a run (Config/Animations.Run): then the DashLeft / DashRight animation plays here.
	The server checks it (RoundService, "Dash": sideways only) and sets DashAt/DashDir on your character so everyone
	sees it, and DashReady on you for the cooldown tile (Screens/PowerBar).
	CATCHERS in a round dive instead (the code still calls it the lunge; owner: "when they press space they jump and haul
	at the runner"; Oct 18: "when you press space to huss with the knife it leaps forward/sideways to catch the person";
	Oct 19: "add a dive feature for the tagger and after they use it they are stunned for 2 seconds"): a low leap the way you steer,
	forward, or sideways while holding A / D (like the runners' huss), never backwards (Shared/KnifeLeap), a hard burst
	easing off (Config/Round.Lunge, same speed and hop either way). The knife's hit box follows the leap (Gameplay/
	HitCheck) and the server checks the catch is possible from where it sees you. The whole body leaps (Shared/StabMotion
	LEAP: the knife leading, the slash the moment it reaches someone, a low landing), on your screen at once
	(Gameplay/Actions.lungeLocal; knife pass 2: it used to wait for the server's echo). Then the diver lies dazed for
	Config/Round.Lunge.Stun seconds (PowerService.stun: speed 0, no stab, no powers; the body doesn't turn meanwhile).
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
local HitCheck = require(script.Parent.HitCheck)
local Library = require(Shared.AnimationLibrary)
local RunMotion = require(Shared.RunMotion)
local KnifeLeap = require(Shared.KnifeLeap)
local PUBLISHED_RUN = require(Shared.Config.Animations).Run ~= "" -- (then Gameplay/RunAnimator is off: play the track)
local TURN = 0.08 -- seconds the body takes to turn for a huss (eased, never a snap)
local TRACK_SPEED = 0.9 -- the published DashLeft/Right (0.4 s) a little slower: its lean held to 0.30 s, like HV

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
	t:Play(0.04, 1, TRACK_SPEED)
	local length = (if t.Length > 0 then t.Length else 0.4) / TRACK_SPEED
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
-- The camera's right along the ground (the huss goes along it), else the body's.
local function screenRight(root: BasePart): Vector3
	local cam = Workspace.CurrentCamera
	local r = if cam then cam.CFrame.RightVector else root.CFrame.RightVector
	r = Vector3.new(r.X, 0, r.Z)
	if r.Magnitude < 0.1 then
		r = Vector3.new(root.CFrame.RightVector.X, 0, root.CFrame.RightVector.Z)
	end
	return r.Unit
end
-- How much you're pushing right on your screen (-1 left ... 1 right): the stick / A-D (already screen-relative),
-- else your move direction against the camera's right.
local function sideways(root: BasePart, move: Vector3): number
	if controls then
		local ok, v = pcall(function() return controls:GetMoveVector() end)
		if ok and typeof(v) == "Vector3" and math.abs(v.X) > 0.3 then
			return v.X
		end
	end
	return Vector3.new(move.X, 0, move.Z):Dot(screenRight(root))
end

-- A push along the ground that eases from cfg.Speed to cfg.EndSpeed over cfg.Time (Shared/RunMotion.pushSpeed),
-- set every frame, plus a steady `carry` velocity (the run you already had). Gone when it ends.
local function push(root: BasePart, name: string, dir: Vector3, carry: Vector3, cfg)
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Name = name
	lv.Attachment0 = attachment
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.xAxis
	lv.SecondaryTangentAxis = Vector3.zAxis
	lv.MaxForce = 1e6
	local start = os.clock()
	local function set(): boolean
		local speed = RunMotion.pushSpeed(cfg, os.clock() - start)
		if not speed or not root.Parent then
			return false
		end
		local v = dir * speed + carry
		lv.PlaneVelocity = Vector2.new(v.X, v.Z)
		return true
	end
	set()
	lv.Parent = root
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not set() then
			conn:Disconnect()
			lv:Destroy()
			attachment:Destroy()
		end
	end)
end

-- Turn the body to face `facing` over TURN seconds (eased), then hold it there until `holdUntil` (os.clock) and
-- give the turning back to Roblox. Shift lock already faces the camera: nothing to do then.
local turning = 0
local diveHold = 0 -- (counts dives: a dive's hold on turning lets go only if no newer one took over)
local function easeTurn(c: Model, h: Humanoid, root: BasePart, facing: Vector3, holdUntil: number)
	if player:GetAttribute("HuzzShiftLock") == true then
		return
	end
	local from = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if from.Magnitude < 0.1 then
		return
	end
	local a0 = math.atan2(-from.X, -from.Z)
	local delta = math.atan2(-facing.X, -facing.Z) - a0
	delta = (delta + math.pi) % (2 * math.pi) - math.pi
	h.AutoRotate = false
	turning += 1
	local mine = turning
	local start = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if mine ~= turning or not root.Parent or root.Anchored then
			conn:Disconnect()
			return
		end
		local now = os.clock()
		local u = math.clamp((now - start) / TURN, 0, 1)
		local s = 1 - (1 - u) * (1 - u) -- (quick, then settling)
		if player:GetAttribute("HuzzShiftLock") ~= true then
			root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, a0 + delta * s, 0)
		end
		if now >= holdUntil then
			conn:Disconnect()
			if h.Parent and not h.AutoRotate and player:GetAttribute("HuzzShiftLock") ~= true
				and c:GetAttribute("DownedAt") == nil and player:GetAttribute("HuzzStatus") ~= "Downed" then
				h.AutoRotate = true -- (a knockdown in the meantime keeps its own hold on turning)
			end
		end
	end)
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
		and player:GetAttribute("HuzzFeetFirst") ~= true -- (just spawned or moved: feet on the floor first, Gameplay/Sprint)
		and c ~= nil and c:GetAttribute("DownedAt") == nil and player:GetAttribute("MenuOpen") ~= true
		and Workspace:GetServerTimeNow() >= (player:GetAttribute("DashReady") or 0)
		and os.clock() - lastLocal >= (if role == "Catcher" and playing then Config.Lunge.Cooldown else Config.Dash.Cooldown) - 0.1
end

-- The catcher's lunge: a hop and a hard push the way you steer (forward, or sideways with A / D; never back).
local function lunge(c: Model, h: Humanoid, root: BasePart)
	local dir = KnifeLeap.direction(root.CFrame.LookVector, h.MoveDirection)
	if not dir then return end
	lastLocal = os.clock()
	local lungeNet = Net.get("Lunge") :: RemoteEvent
	local L = Config.Lunge
	local first, firstShown = HitCheck.find(root, L.Reach, L.Width, dir)
	local Actions = require(script.Parent.Actions)
	if Actions.lungeLocal then Actions.lungeLocal() end -- (the leap's body and knife, now, not a round trip later)
	if first == false then
		lungeNet:FireServer(nil, dir) -- (this build can't check: the server finds who the leap reaches, along dir)
	else
		lungeNet:FireServer(true, dir) -- (true: this screen reports who the leap reaches, Gameplay/HitCheck)
		-- pinpoint: the first runner inside the leaping knife's reach on your screen during the hit window
		task.spawn(function()
			local found, shown = first, firstShown
			local t0 = os.clock()
			-- (until the landing: lying stunned, nobody is caught; the server refuses those too)
			local window = math.min(L.HitWindow, L.StunAfter or L.Time)
			while not found and os.clock() - t0 < window and root.Parent do
				RunService.Heartbeat:Wait()
				found, shown = HitCheck.find(root, L.Reach, L.Width, dir)
			end
			if type(found) == "number" then
				lungeNet:FireServer(found, shown) -- (who, and where this screen showed you both)
				if Actions.lungeHit then Actions.lungeHit() end -- (the slash lands now on your screen)
			end
		end)
	end
	Sfx.play("lunge")
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(v.X, Config.Lunge.Up, v.Z) -- (the hop: jumping itself is off)
	push(root, "HuzzLunge", dir, Vector3.zero, Config.Lunge) -- (a hard burst easing off, not a flat shove and a cut)
	-- the dive ends on your belly, stunned (Config/Round.Lunge.Stun): the body keeps its heading until you're up, or
	-- the keys would turn it round on the floor
	local L = Config.Lunge
	if player:GetAttribute("HuzzShiftLock") ~= true then
		h.AutoRotate = false
		diveHold += 1
		local mine = diveHold
		local function letGo()
			if mine == diveHold and h.Parent and not h.AutoRotate and player:GetAttribute("HuzzShiftLock") ~= true
				and c:GetAttribute("DownedAt") == nil then
				h.AutoRotate = true
			end
			if mine == diveHold then diveHold += 1 end
		end
		task.delay((L.StunAfter or L.Time) + (L.Stun or 0), letGo)
		-- (the server can take the stun away early: PowerService.clear at the end of a Hero run)
		local conn
		conn = player:GetAttributeChangedSignal("StunnedUntil"):Connect(function()
			if mine ~= diveHold then
				conn:Disconnect()
			elseif player:GetAttribute("StunnedUntil") == nil then
				conn:Disconnect()
				letGo()
			end
		end)
	end
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
	-- Left or right on your screen (owner: "make the huss better because it only goes one way": without shift lock
	-- you face the way you walk, so A and D both threw you back toward the camera): along the camera's right.
	local side = Dash.side(root, h.MoveDirection)
	local right = screenRight(root)
	local dir = right * side
	lastSide = side
	-- The body turns (eased, never snapped) to whichever way along the camera's line is nearer, so the move is a
	-- sideways lean for it: at most a quarter turn (facing the camera is fine: then it leans to its own left).
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	local facing = Vector3.new(right.Z, 0, -right.X) -- (the camera's look along the ground)
	if look.Magnitude > 0.1 and look:Dot(facing) < 0 then
		facing = -facing
	end
	easeTurn(c, h, root, facing, os.clock() + Config.Dash.Time + 0.05)
	lastLocal = os.clock()
	local at = Workspace:GetServerTimeNow()
	c:SetAttribute("DashDir", dir) -- on this screen at once; the server sets the same for everyone
	c:SetAttribute("DashAt", at)
	c:SetAttribute("HuzzMyDashAt", at) -- (local only: the server's copy of DashAt arriving later is the same huss, RunMotion.dashAt)
	Net.get("Dash"):FireServer(dir, at, facing) -- (the facing we're turning to: the server may not have it yet)
	Sfx.play("dash")
	if PUBLISHED_RUN then
		local trackSide = if dir:Dot(Vector3.new(-facing.Z, 0, facing.X)) > 0 then 1 else -1 -- (the body's own side)
		playMove(h, trackSide)
	end

	-- The push: sideways, easing off, keeping whatever run you had across it (the huss never adds forward or back).
	local v = root.AssemblyLinearVelocity
	local carry = Vector3.new(v.X, 0, v.Z)
	carry -= dir * carry:Dot(dir)
	if carry.Magnitude > h.WalkSpeed then
		carry = carry.Unit * h.WalkSpeed
	end
	push(root, "HuzzDash", dir, carry, Config.Dash)
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
				if state == Enum.UserInputState.Begin then
					-- sitting (a bench or seat): Space stands you up, as Roblox's jump would
					local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
					if h and h.Sit then
						h.Sit = false
					else
						Dash.try()
					end
				end
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
