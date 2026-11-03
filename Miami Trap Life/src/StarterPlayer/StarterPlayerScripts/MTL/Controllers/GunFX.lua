--!strict
-- Local-only gun effects (Piece 5), used by GunController for your own shots (instantly) and for other players'
-- shots (from GunFx). Everything is pooled: no Instances are made per shot after warm-up, except sound clones.
--   GunFX.muzzle(gunModel)                         flash + light + smoke at the Muzzle attachment
--   GunFX.tracer(from, to)                         a bright streak that flies from -> to
--   GunFX.impact(pos, normal, hitInstance?)        sparks/dust (+ a bullet hole on anchored parts), blood puff on characters
--   GunFX.sound(gunModel, slot, volumeScale?)      plays a Sound from the gun's Handle (Fire, Tail, Empty, Reload...)
--   GunFX.ui(soundId)                              a 2D UI sound (hit tick, kill)
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Guns = require(ReplicatedStorage.MTL.Config.Guns)
local Theme = require(ReplicatedStorage.MTL.UI.Theme)

local G = Theme.Gun
local T = Guns.Tuning

local GunFX = {}

local folder: Folder
local function fxFolder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = Workspace:FindFirstChild("MTL_GunFX_Local") :: Folder?
	if not f then
		local nf = Instance.new("Folder")
		nf.Name = "MTL_GunFX_Local"
		nf.Parent = Workspace
		f = nf
	end
	assert(f)
	folder = f
	return f
end
GunFX.folder = fxFolder

local function fxPart(name: string): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Transparency = 1
	p.Size = Vector3.new(0.1, 0.1, 0.1)
	p.Parent = fxFolder()
	return p
end

---------------------------------------------------------------- muzzle

local function emitter(name: string, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Enabled = false
	e.Rate = 0
	e.LockedToPart = false
	for k, v in props do
		(e :: any)[k] = v
	end
	return e
end

local function muzzleKit(muzzle: Attachment): Attachment
	local kit = muzzle:FindFirstChild("MTL_FlashKit") :: Attachment?
	if kit then
		return kit
	end
	-- attachments can't hold attachments: the kit lives next to the Muzzle, same CFrame
	local a = Instance.new("Attachment")
	a.Name = "MTL_FlashKit"
	a.CFrame = muzzle.CFrame
	local light = Instance.new("PointLight")
	light.Name = "Light"
	light.Color = G.Flash
	light.Brightness = 5
	light.Range = 12
	light.Shadows = false
	light.Enabled = false
	light.Parent = a
	emitter("Flash", {
		Texture = G.FlashTexture,
		Color = ColorSequence.new(G.Flash),
		LightEmission = 1,
		LightInfluence = 0,
		Lifetime = NumberRange.new(0.03, 0.05),
		Speed = NumberRange.new(0),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0.2) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
		Rotation = NumberRange.new(0, 360),
		ZOffset = 0.5,
	}).Parent = a
	emitter("Smoke", {
		Texture = G.SmokeTexture,
		Color = ColorSequence.new(Color3.fromRGB(200, 200, 200)),
		LightInfluence = 1,
		Lifetime = NumberRange.new(0.4, 0.7),
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(15, 15),
		EmissionDirection = Enum.NormalId.Front,
		Acceleration = Vector3.new(0, 2, 0),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.9) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(1, 1) }),
	}).Parent = a
	a.Parent = muzzle.Parent
	-- remember it on the muzzle so we find it next time
	local ref = Instance.new("ObjectValue")
	ref.Name = "MTL_FlashKit"
	ref.Value = a
	ref.Parent = muzzle
	return a
end

local function kitFor(gunModel: Instance?): Attachment?
	if not gunModel then
		return nil
	end
	local muzzle = gunModel:FindFirstChild("Muzzle", true) :: Attachment?
	if not muzzle or not muzzle:IsA("Attachment") then
		return nil
	end
	local ref = muzzle:FindFirstChild("MTL_FlashKit") :: ObjectValue?
	if ref and ref.Value and ref.Value.Parent then
		return ref.Value :: Attachment
	end
	if ref then
		ref:Destroy()
	end
	return muzzleKit(muzzle)
end

function GunFX.muzzlePosition(gunModel: Instance?): Vector3?
	local muzzle = gunModel and gunModel:FindFirstChild("Muzzle", true) :: Attachment?
	if muzzle and muzzle:IsA("Attachment") then
		return muzzle.WorldPosition
	end
	return nil
end

function GunFX.muzzle(gunModel: Instance?)
	local kit = kitFor(gunModel)
	if not kit then
		return
	end
	(kit:FindFirstChild("Flash") :: ParticleEmitter):Emit(2);
	(kit:FindFirstChild("Smoke") :: ParticleEmitter):Emit(1)
	local light = kit:FindFirstChild("Light") :: PointLight
	light.Enabled = true
	task.delay(0.05, function()
		light.Enabled = false
	end)
end

---------------------------------------------------------------- tracers

type Tracer = { part: Part, from: Vector3, dir: Vector3, len: number, t: number, total: number }
local tracerPool: { Part } = {}
local flying: { Tracer } = {}

local function getTracer(): Part
	local p = table.remove(tracerPool)
	if p then
		return p
	end
	local np = fxPart("Tracer")
	np.Color = G.Tracer
	return np
end

function GunFX.tracer(from: Vector3, to: Vector3)
	local d = to - from
	local dist = d.Magnitude
	if dist < 2 then
		return
	end
	local p = getTracer()
	p.Size = Vector3.new(T.TracerWidth, T.TracerWidth, math.min(T.TracerLength, dist))
	p.Transparency = 0.1
	table.insert(flying, { part = p, from = from, dir = d.Unit, len = dist, t = 0, total = math.max(dist / T.TracerSpeed, 1 / 60) })
end

---------------------------------------------------------------- impacts

local impactAtt: Attachment? = nil
local function impactKit(): Attachment
	if impactAtt and impactAtt.Parent then
		return impactAtt
	end
	local a = Instance.new("Attachment")
	a.Name = "MTL_ImpactKit"
	emitter("Sparks", {
		Texture = G.SparkTexture,
		Color = ColorSequence.new(G.Spark),
		LightEmission = 1,
		Lifetime = NumberRange.new(0.08, 0.2),
		Speed = NumberRange.new(10, 22),
		SpreadAngle = Vector2.new(40, 40),
		EmissionDirection = Enum.NormalId.Front,
		Acceleration = Vector3.new(0, -60, 0),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0) }),
		Drag = 4,
	}).Parent = a
	emitter("Dust", {
		Texture = G.SmokeTexture,
		Color = ColorSequence.new(G.Dust),
		Lifetime = NumberRange.new(0.3, 0.6),
		Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(30, 30),
		EmissionDirection = Enum.NormalId.Front,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) }),
		Drag = 3,
	}).Parent = a
	emitter("Blood", {
		Color = ColorSequence.new(G.Blood),
		Lifetime = NumberRange.new(0.15, 0.3),
		Speed = NumberRange.new(3, 7),
		SpreadAngle = Vector2.new(35, 35),
		EmissionDirection = Enum.NormalId.Front,
		Acceleration = Vector3.new(0, -30, 0),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0.05) }),
		Drag = 2,
	}).Parent = a
	a.Parent = Workspace.Terrain
	impactAtt = a
	return a
end

local holes: { Part } = {}
local holeNext = 1

local function hole(pos: Vector3, normal: Vector3)
	local p = holes[holeNext]
	if not p then
		p = fxPart("BulletHole")
		p.Material = Enum.Material.SmoothPlastic
		p.Color = G.Hole
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(0.02, 0.22, 0.22)
		holes[holeNext] = p
	end
	assert(p)
	holeNext = holeNext % T.MaxImpacts + 1
	-- cylinder axis is X: point it along the surface normal
	p.CFrame = CFrame.lookAt(pos + normal * 0.01, pos + normal * 2) * CFrame.Angles(0, math.rad(90), 0)
	p.Transparency = 0.05
	local mine = p
	task.delay(T.ImpactSeconds, function()
		if mine.CFrame.Position:FuzzyEq(pos + normal * 0.01, 0.05) then
			mine.Transparency = 1
		end
	end)
end

local function isCharacterPart(inst: Instance?): boolean
	local cur = inst
	while cur and cur ~= Workspace do
		if cur:IsA("Model") and cur:FindFirstChildOfClass("Humanoid") then
			return true
		end
		cur = cur.Parent
	end
	return false
end
GunFX.isCharacterPart = isCharacterPart

function GunFX.impact(pos: Vector3, normal: Vector3?, hit: Instance?)
	local n = if normal and normal.Magnitude > 0.5 then normal.Unit else Vector3.yAxis
	local kit = impactKit()
	kit.WorldCFrame = CFrame.lookAt(pos, pos + n)
	if isCharacterPart(hit) then
		(kit:FindFirstChild("Blood") :: ParticleEmitter):Emit(4)
		return
	end
	(kit:FindFirstChild("Sparks") :: ParticleEmitter):Emit(5);
	(kit:FindFirstChild("Dust") :: ParticleEmitter):Emit(2)
	if hit and hit:IsA("BasePart") and hit.Anchored and hit.Transparency < 0.5 then
		hole(pos, n)
	end
end

---------------------------------------------------------------- sounds

local function soundsOn(): boolean
	local ok, ClientData = pcall(function()
		return require(script.Parent.ClientData)
	end)
	local d = ok and ClientData.get() or nil
	return not (d and d.Settings and d.Settings.Sound == false)
end

function GunFX.sound(gunModel: Instance?, slot: string, volumeScale: number?)
	if not gunModel or not soundsOn() then
		return
	end
	local handle = gunModel:FindFirstChild("Handle", true)
	local s = handle and handle:FindFirstChild(slot) :: Sound?
	if not s or not s:IsA("Sound") or s.SoundId == "" then
		return
	end
	local c = s:Clone()
	c.Volume = s.Volume * (volumeScale or 1)
	c.PlaybackSpeed = s.PlaybackSpeed * (0.95 + math.random() * 0.1) -- tiny pitch variation so rapid fire isn't robotic
	c.Parent = handle
	c:Play()
	Debris:AddItem(c, 4)
end

local uiSounds: { [string]: Sound } = {}
function GunFX.ui(id: string, volume: number?)
	if id == "" or not soundsOn() then
		return
	end
	local s = uiSounds[id]
	if not s then
		local ns = Instance.new("Sound")
		ns.SoundId = id
		ns.Volume = volume or 0.5
		ns.Parent = SoundService
		uiSounds[id] = ns
		s = ns
	end
	SoundService:PlayLocalSound(s :: Sound)
end

---------------------------------------------------------------- update

function GunFX.init()
	fxFolder()
	RunService.RenderStepped:Connect(function(dt)
		for i = #flying, 1, -1 do
			local f = flying[i]
			f.t += dt
			local a = math.clamp(f.t / f.total, 0, 1)
			local headDist = f.len * a
			local segLen = math.min(f.part.Size.Z, headDist)
			local headPos = f.from + f.dir * headDist
			local mid = headPos - f.dir * (segLen / 2)
			f.part.CFrame = CFrame.lookAt(mid, headPos)
			if a >= 1 then
				f.part.Transparency = 1
				table.insert(tracerPool, f.part)
				table.remove(flying, i)
			end
		end
	end)
end

return GunFX
