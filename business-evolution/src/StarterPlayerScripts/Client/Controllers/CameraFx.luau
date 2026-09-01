--!strict
-- Screen juice: a decaying noise-driven camera shake and a quick FOV punch.
-- The shake is applied AFTER Roblox's camera scripts each frame
-- (RenderPriority.Camera + 1). The offset can never accumulate because the
-- default camera recomputes its CFrame from scratch every frame — we only
-- perturb the finished result.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))

local DEFAULT_SHAKE_SECONDS = 0.45
local MAX_TILT_RADIANS = math.rad(2.4) -- subtle: readable juice, not motion sickness
local MAX_OFFSET_STUDS = 0.4
local NOISE_SPEED = 14
local PUNCH_FOV_DEGREES = 7
local PUNCH_RETURN_SECONDS = 0.35

local CameraFx = {}

local trove = Trove.new()
local trauma = 0
local decayPerSecond = 1 / DEFAULT_SHAKE_SECONDS
local restingFov: number? = nil
local activePunch: Tween? = nil

-- intensity 0..1; duration optional (seconds until fully settled).
function CameraFx.shake(intensity: number, duration: number?)
	local clamped = math.clamp(intensity, 0, 1)
	-- max, not sum: several crits in one frame must not fling the camera.
	trauma = math.max(trauma, clamped)
	decayPerSecond = clamped / math.max(duration or DEFAULT_SHAKE_SECONDS, 0.05)
end

-- Brief FOV push-in that springs back out with Back easing (slight overshoot
-- past resting, which is what sells the "punch").
function CameraFx.zoomPunch()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	-- Remember the pre-punch FOV once, so overlapping punches spring back to
	-- the true resting value instead of ratcheting the FOV downward.
	if restingFov == nil then
		restingFov = camera.FieldOfView
	end
	local base = restingFov :: number

	local current = activePunch
	if current then
		current:Cancel()
	end

	camera.FieldOfView = base - PUNCH_FOV_DEGREES
	local tween = TweenService:Create(
		camera,
		TweenInfo.new(PUNCH_RETURN_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ FieldOfView = base }
	)
	activePunch = tween
	tween:Play()

	task.delay(PUNCH_RETURN_SECONDS + 0.05, function()
		-- Only forget the resting FOV if no newer punch took over meanwhile;
		-- forgetting lets genuine FOV changes (settings, cutscenes) win later.
		if activePunch == tween then
			activePunch = nil
			restingFov = nil
		end
	end)
end

function CameraFx:Init() end

function CameraFx:Start()
	trove:BindToRenderStep("BusinessEvolutionCameraFx", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		if trauma <= 0 then
			return
		end
		trauma = math.max(0, trauma - decayPerSecond * dt)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		-- trauma² is the springy feel: violent right after the hit, melting
		-- away at the tail instead of stopping on a cliff.
		local power = trauma * trauma
		local t = os.clock() * NOISE_SPEED
		-- math.noise is smooth over time and spans roughly [-0.5, 0.5]; the
		-- different second coordinates give uncorrelated channels so the
		-- motion tumbles instead of sliding on a diagonal.
		local tiltX = math.noise(t, 0) * 2 * MAX_TILT_RADIANS * power
		local tiltY = math.noise(t, 11.7) * 2 * MAX_TILT_RADIANS * power
		local slide = Vector3.new(math.noise(t, 23.9), math.noise(t, 37.1), 0) * 2 * MAX_OFFSET_STUDS * power
		camera.CFrame = camera.CFrame * CFrame.new(slide) * CFrame.Angles(tiltX, tiltY, 0)
	end)
end

return CameraFx
