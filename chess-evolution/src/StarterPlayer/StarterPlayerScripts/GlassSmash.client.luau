--!strict
-- +1 Chess Evolution: the glass-smash win (reference clip 1, Nov 8).
-- When you beat a rival, they ragdoll backwards through their stage's glass gate, the glass
-- bursts into shards with a smash and a funny "oof", and both come back a moment later.
-- Client only and only for the winner: nothing here touches saves or rewards. The real rival
-- is hidden on this screen while a local copy flies; the glass is hidden here, not on the server.
-- Sounds are Roblox's own built-in files (rbxasset://sounds/...), so no uploads are needed.
-- Other scripts can trigger it too: ReplicatedStorage.ChessFx.GlassSmash:Fire(stageId)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")

local Net = require(ReplicatedStorage:WaitForChild("Kit"):WaitForChild("Net"))

local TAG = "[GlassSmash]"
local LAUNCH_DELAY = 0.32 -- lands right after the capture beat in ChessClient (0.3 s)
local LAUNCH_SPEED = 55 -- studs/s toward the glass while the push lasts
local LAUNCH_UP = 14
local PUSH_TIME = 0.28 -- a short driven push guarantees they go through the pane
local SHARDS = 18
local RAGDOLL_TIME = 2.6 -- how long the flying copy stays before fading
local GLASS_BACK = 2.4 -- glass rebuilds after this
local RIVAL_BACK = 3.2 -- the real rival pops back on its plate

local settings = { Sound = true, Reduced = false }
local busy: { [string]: boolean } = {}

local fxFolder = Instance.new("Folder")
fxFolder.Name = "GlassSmashFx"
fxFolder.Parent = workspace

---------------------------------------------------------------------------
-- Sounds: built-in files. Name case can differ between platforms, so try both spellings.
---------------------------------------------------------------------------
local SOUND_FILES = {
	Glass = { "glassbreak.wav", "GlassBreak.wav" },
	Oof = { "uuhhh.mp3" },
	Whoosh = { "swordlunge.wav" },
	Ouch = { "Kid saying Ouch.wav", "kid saying ouch.wav" },
	Thud = { "hit.wav" },
}
local soundIds: { [string]: string } = {}
task.spawn(function()
	for key, files in SOUND_FILES do
		for _, file in files do
			local s = Instance.new("Sound")
			s.SoundId = "rbxasset://sounds/" .. file
			s.Volume = 0
			s.Parent = SoundService -- a sound only loads once it is in the game
			pcall(ContentProvider.PreloadAsync, ContentProvider, { s })
			local t0 = os.clock()
			while s.TimeLength == 0 and os.clock() - t0 < 2 do
				task.wait(0.1)
			end
			if s.TimeLength > 0 then
				soundIds[key] = s.SoundId
				s:Destroy()
				break
			end
			s:Destroy()
		end
		if not soundIds[key] then
			warn(`{TAG} sound {key} not found (silent)`)
		end
	end
end)

local function play(key: string, volume: number, pitch: number?, at: Vector3?)
	if not settings.Sound or not soundIds[key] then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = soundIds[key]
	s.Volume = volume
	s.PlaybackSpeed = pitch or 1
	local holder: Instance = SoundService
	if at then
		local p = Instance.new("Attachment")
		p.WorldPosition = at
		p.Parent = workspace.Terrain
		holder = p
		s.RollOffMinDistance = 30
		s.RollOffMaxDistance = 250
	end
	s.Parent = holder
	s:Play()
	task.delay(6, function()
		if holder ~= SoundService then
			holder:Destroy()
		else
			s:Destroy()
		end
	end)
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function stagesFolder(): Instance?
	local map = workspace:FindFirstChild("Map")
	return map and map:FindFirstChild("Stages")
end

-- hide or show a model on this screen only
local function setLocalHidden(model: Instance, amount: number)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			(d :: any).LocalTransparencyModifier = amount
		elseif d:IsA("BillboardGui") then
			d.Enabled = amount < 0.5
		end
	end
end

local function fadeLocalIn(model: Instance, time: number)
	local v = Instance.new("NumberValue")
	v.Value = 1
	v.Changed:Connect(function(a)
		setLocalHidden(model, a)
	end)
	local tw = TweenService:Create(v, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = 0 })
	tw.Completed:Once(function()
		setLocalHidden(model, 0)
		v:Destroy()
	end)
	tw:Play()
end

-- Make the copy go floppy. Avatar rigs made in Studio use AnimationConstraints with ready-made
-- (disabled) BallSocketConstraints: swap them. Older rigs use Motor6Ds: replace each with a socket.
local function ragdoll(rig: Model)
	local hum = rig:FindFirstChildOfClass("Humanoid")
	local animJoints = 0
	for _, d in rig:GetDescendants() do
		if d.ClassName == "AnimationConstraint" and d.Name ~= "Root" then
			(d :: any).Enabled = false
			animJoints += 1
		elseif d:IsA("BallSocketConstraint") then
			d.Enabled = true
		end
	end
	local motors = {}
	for _, d in rig:GetDescendants() do
		if d:IsA("Motor6D") then
			table.insert(motors, d)
		end
	end
	if #motors == 0 and animJoints == 0 and hum then
		pcall(function()
			hum:BuildRigFromAttachments()
		end)
		for _, d in rig:GetDescendants() do
			if d:IsA("Motor6D") then
				table.insert(motors, d)
			end
		end
	end
	for _, m in motors do
		local p0, p1 = m.Part0, m.Part1
		if not p0 or not p1 or p0.Name == "HumanoidRootPart" then
			continue -- keep the root glued to the body
		end
		local a0 = Instance.new("Attachment")
		a0.CFrame = m.C0
		a0.Parent = p0
		local a1 = Instance.new("Attachment")
		a1.CFrame = m.C1
		a1.Parent = p1
		local bs = Instance.new("BallSocketConstraint")
		bs.Attachment0 = a0
		bs.Attachment1 = a1
		bs.LimitsEnabled = true
		bs.UpperAngle = if p1.Name:find("Head") then 35 else 70
		bs.TwistLimitsEnabled = true
		bs.TwistLowerAngle = -40
		bs.TwistUpperAngle = 40
		bs.Parent = p1
		m.Enabled = false
	end
	if hum then
		hum.PlatformStand = true
		pcall(function()
			hum:ChangeState(Enum.HumanoidStateType.Physics)
		end)
	end
	for _, d in rig:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanQuery = false
			d.CanTouch = false
			local isRoot = d.Name == "HumanoidRootPart"
			local isAcc = d.Parent and d.Parent:IsA("Accessory")
			d.CanCollide = not isRoot and not isAcc
			if isAcc then
				d.Massless = true
			end
		elseif d:IsA("BillboardGui") or d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
end

-- Thin glass wedges bursting out of the pane, mostly in the flight direction.
local function shatter(barrier: BasePart, at: Vector3, dir: Vector3)
	local cf = barrier.CFrame
	local half = barrier.Size / 2
	local reduced = settings.Reduced
	local count = if reduced then math.floor(SHARDS / 2) else SHARDS
	local rng = Random.new()
	for i = 1, count do
		local w = Instance.new("WedgePart")
		local s = rng:NextNumber(1.2, 3.4)
		w.Size = Vector3.new(0.15, s, s * rng:NextNumber(0.6, 1.2))
		-- spread over the pane, denser near the hit point
		local local0 = cf:PointToObjectSpace(at)
		local x = math.clamp(local0.X + rng:NextNumber(-1, 1) * half.X * (if i <= count / 2 then 0.35 else 1), -half.X, half.X)
		local y = math.clamp(local0.Y + rng:NextNumber(-1, 1) * half.Y * (if i <= count / 2 then 0.35 else 1), -half.Y, half.Y)
		w.CFrame = cf * CFrame.new(x, y, 0) * CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28))
		w.Material = Enum.Material.Glass
		w.Color = barrier.Color
		w.Transparency = math.clamp(barrier.Transparency - 0.15, 0.2, 0.7)
		w.Reflectance = 0.2
		w.CanCollide = true
		w.CanQuery = false
		w.CanTouch = false
		w.CastShadow = false
		w.Massless = false
		w.Parent = fxFolder
		local side = dir:Cross(Vector3.yAxis)
		local out = dir * rng:NextNumber(18, 42) + side * rng:NextNumber(-12, 12) + Vector3.new(0, rng:NextNumber(4, 22), 0)
		w.AssemblyLinearVelocity = out
		w.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-18, 18), rng:NextNumber(-18, 18), rng:NextNumber(-18, 18))
		task.delay(1.6 + rng:NextNumber(0, 0.6), function()
			if w.Parent then
				local tw = TweenService:Create(w, TweenInfo.new(0.5), { Transparency = 1 })
				tw.Completed:Once(function()
					w:Destroy()
				end)
				tw:Play()
			end
		end)
	end
	-- glitter puff at the hole (built-in sparkle texture, no flash)
	local a = Instance.new("Attachment")
	a.WorldPosition = at
	a.Parent = workspace.Terrain
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(Color3.fromRGB(220, 245, 255))
	pe.LightEmission = 0.6
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	pe.Lifetime = NumberRange.new(0.4, 0.8)
	pe.Speed = NumberRange.new(14, 30)
	pe.SpreadAngle = Vector2.new(70, 70)
	pe.Drag = 4
	pe.EmissionDirection = Enum.NormalId.Front
	pe.Enabled = false
	pe.Parent = a
	a.CFrame = CFrame.lookAt(at, at + dir) - at
	pe:Emit(if reduced then 12 else 28)
	task.delay(1.5, function()
		a:Destroy()
	end)
end

---------------------------------------------------------------------------
-- The moment
---------------------------------------------------------------------------
local function smash(stageId: string)
	if busy[stageId] then
		return
	end
	local stages = stagesFolder()
	local stage = stages and stages:FindFirstChild(stageId)
	local npc = stage and stage:FindFirstChild("RivalNPC") :: Model?
	local gate = stage and stage:FindFirstChild("Gate")
	local barrier = gate and gate:FindFirstChild("Barrier") :: BasePart?
	if not stage or not npc or not barrier then
		warn(`{TAG} {stageId}: missing RivalNPC or Gate.Barrier, skipped`)
		return
	end
	local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	busy[stageId] = true

	-- straight back through the pane (along its normal, toward it), level, plus a hop
	local from = root.Position
	local n = barrier.CFrame.LookVector
	local toPane = barrier.Position - from
	local flatN = Vector3.new(n.X, 0, n.Z)
	local dir = if flatN.Magnitude > 0.1 then flatN.Unit * (if toPane:Dot(n) >= 0 then 1 else -1) else -root.CFrame.LookVector
	local flat = Vector3.new(toPane.X, 0, toPane.Z)
	local denom = dir:Dot(n)
	local dist = if math.abs(denom) > 0.05 then (barrier.Position - from):Dot(n) / denom else flat.Magnitude
	local hit = from + dir * dist + Vector3.new(0, 2, 0)

	-- the flying copy
	local wasArchivable = npc.Archivable
	npc.Archivable = true
	local copy = npc:Clone()
	npc.Archivable = wasArchivable
	if not copy then
		busy[stageId] = nil
		return
	end
	copy.Name = "RivalRagdoll"
	setLocalHidden(npc, 1)
	copy.Parent = fxFolder
	ragdoll(copy)
	local rng = Random.new()
	local spinAxis = dir:Cross(Vector3.yAxis)
	-- a plain velocity kick gets eaten by the rig, so drive the torso for a moment, then let go
	local copyRoot = copy:FindFirstChild("UpperTorso") or copy:FindFirstChild("HumanoidRootPart")
	if copyRoot and copyRoot:IsA("BasePart") then
		local att = Instance.new("Attachment")
		att.Parent = copyRoot
		local lv = Instance.new("LinearVelocity")
		lv.Attachment0 = att
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.MaxForce = 1e6
		lv.VectorVelocity = dir * LAUNCH_SPEED + Vector3.new(0, LAUNCH_UP, 0)
		lv.Parent = copyRoot
		local av = Instance.new("AngularVelocity")
		av.Attachment0 = att
		av.RelativeTo = Enum.ActuatorRelativeTo.World
		av.MaxTorque = 1e5
		av.AngularVelocity = -spinAxis * rng:NextNumber(7, 11) + Vector3.new(0, rng:NextNumber(-3, 3), 0)
		av.Parent = copyRoot
		task.delay(PUSH_TIME, function()
			lv:Destroy()
			av:Destroy()
		end)
	end
	play("Whoosh", 0.6, 1.1)
	play("Oof", 0.9, rng:NextNumber(0.95, 1.1))

	-- break the glass when the body reaches it (or after a short timeout)
	local broke = false
	local oldT = barrier.Transparency
	local function breakGlass()
		if broke then
			return
		end
		broke = true
		barrier.Transparency = 1 -- this screen only; the server copy is untouched
		shatter(barrier, hit, dir)
		play("Glass", 1, rng:NextNumber(0.95, 1.08), hit)
		task.delay(0.45, function()
			play("Ouch", 0.7, 1.05)
		end)
		task.delay(0.7, function()
			play("Thud", 0.5, 0.8)
		end)
		task.delay(GLASS_BACK, function()
			if barrier.Parent then
				barrier.Transparency = 1
				TweenService:Create(barrier, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Transparency = oldT }):Play()
			end
		end)
	end
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local part = copyRoot :: BasePart?
		if not part or not part.Parent then
			conn:Disconnect()
			breakGlass()
			return
		end
		local side = barrier.CFrame:PointToObjectSpace(part.Position).Z
		local startSide = barrier.CFrame:PointToObjectSpace(from).Z
		if (side > 0) ~= (startSide > 0) or math.abs(side) < 1 or os.clock() - t0 > 0.6 then
			conn:Disconnect()
			breakGlass()
		end
	end)

	-- clean up: fade the copy, bring the real rival back
	task.delay(RAGDOLL_TIME, function()
		for _, d in copy:GetDescendants() do
			if d:IsA("BasePart") then
				TweenService:Create(d, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			elseif d:IsA("Decal") then
				TweenService:Create(d, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			end
		end
		task.delay(0.45, function()
			copy:Destroy()
		end)
	end)
	task.delay(RIVAL_BACK, function()
		if npc.Parent then
			fadeLocalIn(npc, 0.35)
		end
		busy[stageId] = nil
	end)
	print(`{TAG} {stageId}: smash`)
end

---------------------------------------------------------------------------
-- Wiring
---------------------------------------------------------------------------
Net.On("State", function(snap: any)
	if snap and snap.Settings then
		settings.Sound = snap.Settings.Sound ~= false
		settings.Reduced = snap.Settings.Reduced == true
	end
end)

Net.On("BattleEnd", function(p: any)
	if p and p.outcome == "win" and type(p.stage) == "string" then
		task.delay(LAUNCH_DELAY, function()
			local ok, err = pcall(smash, p.stage)
			if not ok then
				warn(`{TAG} failed: {err}`)
				busy[p.stage] = nil
			end
		end)
	end
end)

-- a hook for other client code (auto wins, previews)
local fx = ReplicatedStorage:FindFirstChild("ChessFx")
if not fx then
	fx = Instance.new("Folder")
	fx.Name = "ChessFx"
	fx.Parent = ReplicatedStorage
end
local ev = (fx :: Instance):FindFirstChild("GlassSmash") :: BindableEvent?
if not ev then
	local e = Instance.new("BindableEvent")
	e.Name = "GlassSmash"
	e.Parent = fx
	ev = e
end
(ev :: BindableEvent).Event:Connect(function(stageId: string)
	local ok, err = pcall(smash, stageId)
	if not ok then
		warn(`{TAG} failed: {err}`)
		busy[stageId] = nil
	end
end)

print(`{TAG} ready`)
