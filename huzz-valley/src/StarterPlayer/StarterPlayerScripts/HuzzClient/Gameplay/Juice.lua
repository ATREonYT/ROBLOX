--[[
	Reward bursts for the big moments, in the world (owner: "it looks still a bit bland and plain, i want it to feel
	nice, play nice and give people enjoyment"; the write-up "making it feel great" picked this first). Everyone sees:
	  - someone reaches safety: a green ring spreads over the floor and confetti pops up from them;
	  - someone gets caught: a red ring and a burst of red sparks where they fell;
	  - someone is saved: a column of green sparkles rises from them.
	On your own screen the camera gives a short, small shake when YOU are caught or YOU catch someone (0.25 s,
	fading), and a softer one when you reach safety. Rings and bursts never flash the screen; the shake is off with
	the Reduced Motion setting. RoundHud keeps the words (SAFE!, FIRST!, YOU'RE DOWN); this file only adds the world.
]]
local M = {}

function M.start()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local TweenService = game:GetService("TweenService")
	local Workspace = game:GetService("Workspace")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Net = require(Shared.Net)
	local AuraLook = require(Shared.AuraLook)
	local State = require(script.Parent.Parent.UI.State)

	local player = Players.LocalPlayer
	local GREEN = Color3.fromRGB(91, 224, 122) -- (Huss Valley green, Theme.Colors.Accent)
	local RED = Color3.fromRGB(255, 84, 96)
	local CONFETTI = { Color3.fromRGB(91, 224, 122), Color3.fromRGB(90, 160, 255), Color3.fromRGB(255, 120, 210), Color3.fromRGB(175, 110, 255), Color3.fromRGB(255, 255, 255) }
	local NEAR = 160 -- studs: bursts further from the camera than this are skipped
	local SPARK = AuraLook.TEXTURES.Star or "rbxasset://textures/particles/sparkles_main.dds"

	local function calm()
		return State.setting("ReducedMotion") == true
	end

	local function rootOf(id: number?): BasePart?
		local p = id and Players:GetPlayerByUserId(id)
		local root = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		return if root and root:IsA("BasePart") then root else nil
	end

	local function near(at: Vector3): boolean
		local cam = Workspace.CurrentCamera
		return cam ~= nil and (cam.CFrame.Position - at).Magnitude < NEAR
	end

	-- The floor height under a spot (characters ignored), else 2.9 studs below it.
	local function floorY(at: Vector3): number
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local skip = {}
		for _, p in Players:GetPlayers() do
			if p.Character then table.insert(skip, p.Character) end
		end
		params.FilterDescendantsInstances = skip
		local hit = Workspace:Raycast(at + Vector3.new(0, 1, 0), Vector3.new(0, -12, 0), params)
		return if hit then hit.Position.Y else at.Y - 2.9
	end

	-- A flat glowing ring on the floor that spreads out and fades over 0.6 s.
	local function ring(at: Vector3, color: Color3, size: number)
		local r = Instance.new("Part")
		r.Name = "HuzzRing"
		r.Shape = Enum.PartType.Cylinder
		r.Anchored, r.CanCollide, r.CanQuery, r.CanTouch, r.CastShadow = true, false, false, false, false
		r.Material = Enum.Material.Neon
		r.Color = color
		r.Transparency = 0.35
		r.Size = Vector3.new(0.08, 2, 2)
		r.CFrame = CFrame.new(at.X, floorY(at) + 0.06, at.Z) * CFrame.Angles(0, 0, math.rad(90))
		r.Parent = Workspace
		local info = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(r, info, { Size = Vector3.new(0.08, size, size), Transparency = 1 }):Play()
		task.delay(0.7, function() r:Destroy() end)
	end

	-- A one-shot burst of particles at a spot.
	local function burst(at: Vector3, colors: { Color3 }, count: number, opts: { [string]: any }?)
		local o = opts or {}
		local holder = Instance.new("Part")
		holder.Name = "HuzzBurst"
		holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch, holder.Transparency = true, false, false, false, 1
		holder.Size = Vector3.one
		holder.CFrame = CFrame.new(at)
		holder.Parent = Workspace
		for _, c in colors do
			local e = Instance.new("ParticleEmitter")
			e.Texture = o.texture or SPARK
			e.Color = ColorSequence.new(c)
			e.LightEmission = o.glow or 0.6
			e.Rate = 0
			e.Lifetime = o.life or NumberRange.new(0.7, 1.2)
			e.Speed = o.speed or NumberRange.new(10, 18)
			e.SpreadAngle = o.spread or Vector2.new(35, 35)
			e.EmissionDirection = Enum.NormalId.Top
			e.Acceleration = o.gravity or Vector3.new(0, -30, 0)
			e.Drag = o.drag or 1.5
			e.RotSpeed = NumberRange.new(-220, 220)
			e.Rotation = NumberRange.new(0, 360)
			e.Size = o.size or NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.15) })
			e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0.2), NumberSequenceKeypoint.new(1, 1) })
			e.Parent = holder
			e:Emit(math.max(1, math.floor(count / #colors)))
		end
		task.delay(2, function() holder:Destroy() end)
	end

	-- A short camera shake that fades out (strength in studs).
	local shakeUntil, shakeTime, shakeStrength = 0, 0.25, 0
	local function shake(strength: number, seconds: number)
		if calm() then return end
		shakeStrength = math.max(shakeStrength, strength)
		shakeTime = seconds
		shakeUntil = os.clock() + seconds
	end
	RunService:BindToRenderStep("HuzzShake", Enum.RenderPriority.Camera.Value + 1, function()
		local left = shakeUntil - os.clock()
		local cam = Workspace.CurrentCamera
		if left <= 0 or not cam then
			shakeStrength = 0
			return
		end
		local k = shakeStrength * (left / shakeTime)
		cam.CFrame = cam.CFrame * CFrame.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
	end)

	local function safeFx(id: number)
		local root = rootOf(id)
		if not (root and near(root.Position)) then return end
		ring(root.Position, GREEN, 16)
		burst(root.Position + Vector3.new(0, 1, 0), CONFETTI, 40, {
			texture = "rbxasset://textures/particles/sparkles_main.dds",
			speed = NumberRange.new(16, 26), spread = Vector2.new(30, 30), gravity = Vector3.new(0, -40, 0), glow = 0.3,
			size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0.3) }),
			life = NumberRange.new(1, 1.6),
		})
		if id == player.UserId then shake(0.12, 0.2) end
	end

	-- Everyone's crossing: watch each runner's status turn Safe.
	local function watch(p: Player)
		local last = p:GetAttribute("HuzzStatus")
		p:GetAttributeChangedSignal("HuzzStatus"):Connect(function()
			local now = p:GetAttribute("HuzzStatus")
			if now == "Safe" and last ~= "Safe" and p:GetAttribute("HuzzRole") == "Runner" then
				safeFx(p.UserId)
			end
			last = now
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do watch(p) end

	Net.get("Round").OnClientEvent:Connect(function(kind, data)
		if type(data) ~= "table" then return end
		if kind == "Caught" then
			local root = rootOf(data.runner)
			if root and near(root.Position) then
				ring(root.Position, RED, 12)
				burst(root.Position, { RED, Color3.new(1, 1, 1) }, 26, { speed = NumberRange.new(8, 16), spread = Vector2.new(70, 70) })
			end
			if data.runner == player.UserId then
				shake(0.35, 0.25)
			elseif data.catcher == player.UserId then
				shake(0.2, 0.18)
			end
		elseif kind == "Rescued" then
			local root = rootOf(data.runner)
			if root and near(root.Position) then
				ring(root.Position, GREEN, 10)
				burst(root.Position - Vector3.new(0, 2, 0), { GREEN, Color3.new(1, 1, 1) }, 30, {
					speed = NumberRange.new(5, 9), spread = Vector2.new(12, 12), gravity = Vector3.new(0, 4, 0), drag = 0.5,
					life = NumberRange.new(1, 1.5),
				})
			end
		end
	end)
end

return M
