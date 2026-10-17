--[[
	Reward bursts for the big moments, in the world (owner: "it looks still a bit bland and plain, i want it to feel
	nice, play nice and give people enjoyment"; the write-up "making it feel great" picked this first). One world
	effect per moment, next to the coloured message line (docs/feel-study.md gap 15: "they pile up"). Everyone sees:
	  - someone reaches safety: confetti pops up from them;
	  - someone gets caught: a quick burst of red sparks with a white core where they fell;
	  - someone is saved: a ring of green light lifts off the floor round them, sparkles drifting up inside it;
	  - the game is won: hearts and sparkles in the girl's rarity colour rise round the winner (she flies to them).
	On your own screen the camera shakes (owner: "make the game more cinematic ... more screenshake"): hard when YOU
	are caught, firm when YOU catch someone, a bump at GO, all fading out fast (none on a huss or lunge: Huss Valley has none). While you
	run, the screen edges glow red as a catcher closes in (owner: "a red glow if a catcher is getting near"),
	stronger the closer they are, with a slow heartbeat swell (about once a second, never a flash) when they're right
	on you. Bursts never flash the screen; the shake and the swell are off with the Reduced Motion setting (the glow
	stays: it tells you something). RoundHud keeps the words (SAFE!, FIRST!, YOU'RE DOWN); this file only adds the
	world (the huss speed lines are Gameplay/Feel's). Getting caught also drains the colour from
	your screen with a red tint for half a second (one per catch). Rings are real rings (Gameplay/Burst), not discs.
]]
local M = {}

function M.start()
	local CollectionService = game:GetService("CollectionService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local TweenService = game:GetService("TweenService")
	local Workspace = game:GetService("Workspace")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Net = require(Shared.Net)
	local AuraLook = require(Shared.AuraLook)
	local Round = require(Shared.Config.Round)
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

	local Burst = require(script.Parent.Burst)

	-- The floor height under a spot (characters ignored), else 2.9 studs below it.
	local function floorY(at: Vector3): number
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local skip = { Burst.home() }
		for _, p in Players:GetPlayers() do
			if p.Character then table.insert(skip, p.Character) end
		end
		params.FilterDescendantsInstances = skip
		local hit = Workspace:Raycast(at + Vector3.new(0, 1, 0), Vector3.new(0, -12, 0), params)
		return if hit then hit.Position.Y else at.Y - 2.9
	end

	-- A one-off burst of particles at a spot (Gameplay/Burst).
	local function burst(at: Vector3, colors: { Color3 }, count: number, opts: { [string]: any }?)
		local o = table.clone(opts or {})
		o.texture = o.texture or SPARK
		o.life = o.life or NumberRange.new(0.7, 1.2)
		o.speed = o.speed or NumberRange.new(10, 18)
		o.spread = o.spread or Vector2.new(35, 35)
		o.gravity = o.gravity or Vector3.new(0, -30, 0)
		o.drag = o.drag or 1.5
		o.size = o.size or NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.15) })
		Burst.sparks(at, colors, count, o)
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
		burst(root.Position + Vector3.new(0, 1, 0), CONFETTI, 40, {
			texture = "rbxasset://textures/particles/sparkles_main.dds",
			speed = NumberRange.new(16, 26), spread = Vector2.new(30, 30), gravity = Vector3.new(0, -40, 0), glow = 0.3,
			size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0.3) }),
			life = NumberRange.new(1, 1.6),
		})
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
				burst(root.Position, { RED, RED, Color3.new(1, 1, 1) }, 30, {
					speed = NumberRange.new(10, 20), spread = Vector2.new(80, 80), gravity = Vector3.new(0, -24, 0), drag = 3,
					life = NumberRange.new(0.35, 0.6), glow = 0.8,
				})
			end
			if data.runner == player.UserId then
				shake(0.7, 0.4)
			elseif data.catcher == player.UserId then
				shake(0.4, 0.25)
			end
		elseif kind == "Rescued" then
			local root = rootOf(data.runner)
			if root and near(root.Position) then
				-- one effect: a ring of green light lifts off the floor round them, sparkles drift up inside it
				local base = Vector3.new(root.Position.X, floorY(root.Position) + 0.1, root.Position.Z)
				Burst.ring(CFrame.new(base), {
					r0 = 2.6, r1 = 2.2, time = 0.9, width = 0.16, glow = 0.6, color = GREEN, edge = GREEN, fade = 0.4,
					follow = function(k) return CFrame.new(base + Vector3.new(0, 5 * Burst.ease(k), 0)) end,
				})
				burst(base, { GREEN, Color3.new(1, 1, 1) }, 24, {
					speed = NumberRange.new(5, 9), spread = Vector2.new(12, 12), gravity = Vector3.new(0, 4, 0), drag = 0.5,
					life = NumberRange.new(1, 1.5),
				})
			end
		elseif kind == "Win" and type(data.winner) == "number" and not data.bot then
			-- the reward moment: hearts and sparkles in her rarity colour rise round the winner as she flies to them
			local root = rootOf(data.winner)
			if root and near(root.Position) then
				local color = GREEN
				for _, r in Round.Rarities do
					if r.Name == data.rarity then
						color = if r.Name == "Secret" then Color3.fromRGB(200, 170, 255) else r.Color
					end
				end
				burst(root.Position, { color, Burst.PINK, Color3.new(1, 1, 1) }, 36, {
					speed = NumberRange.new(6, 11), spread = Vector2.new(25, 25), gravity = Vector3.new(0, 3, 0), drag = 0.8,
					life = NumberRange.new(1.2, 1.8), glow = 0.7,
				})
			end
		end
	end)

	-- More shake: a bump at GO. (No shake or smear on a huss or lunge: Huss Valley has none; Gameplay/Feel draws
	-- its thin speed lines.)
	local round = Net.get("Round")
	round:GetAttributeChangedSignal("Stage"):Connect(function()
		local role = player:GetAttribute("HuzzRole")
		if round:GetAttribute("Stage") == "Running" and (role == "Runner" or role == "Catcher") then shake(0.3, 0.3) end
	end)
	-- Getting caught: the screen loses its colour and tints red, then eases back (one per catch, never a flash).
	local Lighting = game:GetService("Lighting")
	local hit = Lighting:FindFirstChild("HuzzHit") or Instance.new("ColorCorrectionEffect")
	hit.Name = "HuzzHit"
	hit.Parent = Lighting
	local function hurt()
		if calm() then return end
		hit.TintColor, hit.Saturation, hit.Contrast = Color3.fromRGB(255, 170, 170), -0.6, 0.1
		TweenService:Create(hit, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TintColor = Color3.new(1, 1, 1), Saturation = 0, Contrast = 0 }):Play()
	end
	Net.get("Round").OnClientEvent:Connect(function(kind, data)
		if kind == "Caught" and type(data) == "table" and data.runner == player.UserId then hurt() end
	end)

	-- The red edge glow: four soft gradients round the screen, under the HUD.
	local edgeGui = Instance.new("ScreenGui")
	edgeGui.Name = "HuzzDanger"
	edgeGui.IgnoreGuiInset = true
	edgeGui.ResetOnSpawn = false
	edgeGui.DisplayOrder = 1
	local edges = {}
	for _, e in {
		{ "Top", UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.24), 90 },
		{ "Bottom", UDim2.fromScale(0, 0.76), UDim2.fromScale(1, 0.24), 270 },
		{ "Left", UDim2.fromScale(0, 0), UDim2.fromScale(0.16, 1), 0 },
		{ "Right", UDim2.fromScale(0.84, 0), UDim2.fromScale(0.16, 1), 180 },
	} do
		local f = Instance.new("Frame")
		f.Name = e[1]
		f.Position, f.Size = e[2], e[3]
		f.BackgroundColor3 = Color3.fromRGB(255, 30, 50)
		f.BackgroundTransparency = 1
		f.BorderSizePixel = 0
		f.Active = false
		local g = Instance.new("UIGradient")
		g.Rotation = e[4]
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.45, 0.6), NumberSequenceKeypoint.new(1, 1) })
		g.Parent = f
		f.Parent = edgeGui
		table.insert(edges, f)
	end
	edgeGui.Parent = player:WaitForChild("PlayerGui")
	local FAR, CLOSE = 40, 8 -- studs: the glow starts at FAR and is full at CLOSE
	local glow = 0
	RunService.Heartbeat:Connect(function(dt)
		local want = 0
		local stage = round:GetAttribute("Stage")
		local me = rootOf(player.UserId)
		local status = player:GetAttribute("HuzzStatus")
		local moving = stage == "Running" or (stage == "HeroRun" and player:GetAttribute("HuzzHero") == true) -- (waiting runners can't be reached)
		if me and player:GetAttribute("HuzzRole") == "Runner" and moving
			and status ~= "Safe" and status ~= "Downed" then
			local nearest = math.huge
			for _, p in Players:GetPlayers() do
				local pc = p.Character
				if p ~= player and p:GetAttribute("HuzzRole") == "Catcher" and p:GetAttribute("HuzzFrozen") ~= true
					and not (pc and pc:GetAttribute("DownedAt")) then
					local r = rootOf(p.UserId)
					if r then nearest = math.min(nearest, (r.Position - me.Position).Magnitude) end
				end
			end
			for _, bot in CollectionService:GetTagged("HuzzBot") do -- (the Practice Bot catches too)
				local r = bot:GetAttribute("HuzzFrozen") ~= true and bot:FindFirstChild("HumanoidRootPart")
				if r and r:IsA("BasePart") then nearest = math.min(nearest, (r.Position - me.Position).Magnitude) end
			end
			want = math.clamp((FAR - nearest) / (FAR - CLOSE), 0, 1)
		end
		glow += (want - glow) * math.min(1, dt * 6) -- eased, so it never pops
		local k = glow
		if k > 0.6 and not calm() then
			k *= 0.85 + 0.15 * math.sin(os.clock() * math.pi * 2) -- the heartbeat swell, once a second
		end
		for _, f in edges do f.BackgroundTransparency = 1 - k * 0.6 end
	end)
end

return M
