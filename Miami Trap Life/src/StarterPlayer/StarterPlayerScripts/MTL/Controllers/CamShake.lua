--!strict
-- Camera shake + hit-stop (LihFolk build list item 3). Helper of GunController (required + init'd by it).
-- One trauma value per client: shots, hits and downs add to it, it fades by Feel.Decay per second, and the camera
-- shakes by trauma^2 on smooth noise (small things barely move it, big things really do). While aiming the rotation
-- is scaled by tan(FOV/2) / tan(35 deg) so a zoomed-in view doesn't shake harder. Settings.Shake (0-100, default
-- 100) and Settings.ReducedMotion scale it. The offset is taken back out before the camera scripts run each frame,
-- so shake never drifts your aim.
-- Hit-stop: a confirmed hit freezes the victim's animation on your screen for a beat (Feel.HitStop), at most Cap
-- seconds in any Window, so a spray doesn't stutter.
--   CamShake.add(trauma, cap?)    cap = own shots can't build trauma past this
--   CamShake.hitStop(model, seconds)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Guns = require(ReplicatedStorage.MTL.Config.Guns)
local ClientData = require(script.Parent.ClientData)

local F = Guns.Feel
local REF = math.tan(math.rad(35))

local CamShake = {}

local trauma = 0
local applied = CFrame.identity
local seed = math.random() * 1000
local clock = 0
local stops: { { at: number, len: number } } = {}
local started = false

local function settingScale(): number
	local d = ClientData.get()
	local s = d and d.Settings
	local pct = 1
	if s and type(s.Shake) == "number" then
		pct = math.clamp(s.Shake, 0, 100) / 100
	end
	if s and s.ReducedMotion == true then
		pct *= F.ReducedMotion
	end
	return pct
end

function CamShake.add(amount: number, cap: number?)
	if type(amount) ~= "number" or amount <= 0 then
		return
	end
	local limit = math.min(1, cap or 1)
	if trauma < limit then
		trauma = math.min(limit, trauma + amount)
	end
end

function CamShake.trauma(): number
	return trauma
end

-- Freezes this model's animation tracks for `seconds` (trimmed to the hit-stop budget).
function CamShake.hitStop(model: Instance?, seconds: number)
	if typeof(model) ~= "Instance" or not model:IsA("Model") or seconds <= 0 then
		return
	end
	local now = os.clock()
	local used = 0
	for i = #stops, 1, -1 do
		local s = stops[i]
		if now - s.at > F.HitStop.Window then
			table.remove(stops, i)
		else
			used += s.len
		end
	end
	local len = math.min(seconds, F.HitStop.Cap - used)
	if len < 0.015 then
		return
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	table.insert(stops, { at = now, len = len })
	local frozen: { [AnimationTrack]: number } = {}
	for _, track in animator:GetPlayingAnimationTracks() do
		if track.Speed ~= 0 then
			frozen[track] = track.Speed
			track:AdjustSpeed(0)
		end
	end
	task.delay(len, function()
		for track, speed in frozen do
			if track.IsPlaying and track.Speed == 0 then
				track:AdjustSpeed(speed)
			end
		end
	end)
end

local function noise(axis: number): number
	return math.clamp(math.noise(seed + axis * 31.7, clock * F.Frequency) * 2, -1, 1)
end

-- before the camera scripts: take last frame's offset back out
local function undo()
	if applied ~= CFrame.identity then
		local cam = Workspace.CurrentCamera
		if cam.CameraType == Enum.CameraType.Custom then
			cam.CFrame = cam.CFrame * applied:Inverse()
		end
		applied = CFrame.identity
	end
end

-- after the camera scripts (and GunController's recoil): put this frame's offset on
local function apply(dt: number)
	clock += dt
	if trauma <= 0 then
		return
	end
	trauma = math.max(0, trauma - F.Decay * dt)
	local cam = Workspace.CurrentCamera
	if cam.CameraType ~= Enum.CameraType.Custom then
		return
	end
	local fovScale = math.clamp(math.tan(math.rad(cam.FieldOfView / 2)) / REF, 0.2, 1.5)
	local k = trauma * trauma * settingScale() * fovScale
	if k <= 0.0005 then
		return
	end
	applied = CFrame.Angles(math.rad(F.MaxPitch * k * noise(1)), math.rad(F.MaxYaw * k * noise(2)), math.rad(F.MaxRoll * k * noise(3)))
	cam.CFrame = cam.CFrame * applied
end

function CamShake.init()
	if started then
		return
	end
	started = true
	RunService:BindToRenderStep("MTL_ShakeUndo", Enum.RenderPriority.Camera.Value - 2, undo)
	RunService:BindToRenderStep("MTL_ShakeApply", Enum.RenderPriority.Camera.Value + 2, apply)
	Players.LocalPlayer.CharacterAdded:Connect(function()
		trauma = 0
	end)
end

return CamShake
