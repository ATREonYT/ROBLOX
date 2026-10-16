--[[
	The small things that make running feel quick and expensive (owner: "make the running/game feel more
	premium... see the feel in Huss Valley"), on this screen only:
	  - the camera widens as you build up to full sprint (owner: "when you are running full speed make the screen
	    make you feel like you are running quick") and kicks wider for a moment when you dash, easing back (never
	    snapping); near full speed soft wind streaks drift outward round the screen edge (fading in and out with
	    your speed, never flashing);
	  - a dash draws a ring of thin speed lines round the screen edge for a quarter of a second (one per dash;
	    the dash cooldown keeps it far under one flash a second);
	  - every runner near you kicks up a little dust each step and a puff when they dash; your own steps make
	    a quiet sound (Sfx "step").
	The sprint feel works in the lobby too; the dust only in a round. Never while the intro camera has the view, and
	off with the Reduced Motion setting (camera, lines and streaks; the dust stays).
]]
local M = {}

function M.start()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local TweenService = game:GetService("TweenService")
	local Workspace = game:GetService("Workspace")

	local Run = require(ReplicatedStorage:WaitForChild("Shared").Config.Run)
	local State = require(script.Parent.Parent.UI.State)
	local Sfx = require(script.Parent.Sfx)
	local Frame = require(script.Parent.Frame)

	local player = Players.LocalPlayer
	local SPRINT_FOV = 11 -- extra degrees at full sprint (was 6: the owner couldn't feel it)
	local DASH_FOV = 9 -- extra degrees at the start of a dash, easing out over DASH_TIME
	local DASH_TIME = 0.45
	local NEAR = 120 -- studs: dust only for runners this close to the camera

	local function inRound(p)
		local role = p:GetAttribute("HuzzRole")
		return role == "Runner" or role == "Catcher"
	end
	local function calm()
		return State.setting("ReducedMotion") == true
	end

	-- Speed lines: thin white bars pointing at the middle of the screen, round the edge.
	local gui = Instance.new("ScreenGui")
	gui.Name = "HuzzFeel"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1
	local lines = {}
	for i = 1, 18 do
		local angle = (i / 18) * math.pi * 2 + (i % 2) * 0.09
		local bar = Instance.new("Frame")
		bar.Name = "Line" .. i
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5 + math.cos(angle) * 0.47, 0.5 + math.sin(angle) * 0.47)
		bar.Size = UDim2.new(0.16 + (i % 3) * 0.04, 0, 0, 2 + i % 2)
		bar.Rotation = math.deg(angle)
		bar.BackgroundColor3 = Color3.new(1, 1, 1)
		bar.BackgroundTransparency = 1
		bar.BorderSizePixel = 0
		bar.Parent = gui
		lines[i] = bar
	end
	-- Wind streaks for full sprint: thin bars round the edge that drift outward on a loop; their see-through
	-- follows your speed smoothly.
	local streaks = {}
	for i = 1, 14 do
		local angle = (i / 14) * math.pi * 2 + 0.11 * (i % 3)
		local bar = Instance.new("Frame")
		bar.Name = "Streak" .. i
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Size = UDim2.new(0.09 + (i % 4) * 0.025, 0, 0, if i % 2 == 0 then 2 else 1)
		bar.Rotation = math.deg(angle)
		bar.BackgroundColor3 = Color3.new(1, 1, 1)
		bar.BackgroundTransparency = 1
		bar.BorderSizePixel = 0
		bar.Parent = gui
		streaks[i] = { bar = bar, angle = angle, phase = (i * 0.37) % 1 }
	end
	local streakClock = 0
	gui.Parent = player:WaitForChild("PlayerGui")
	local function speedLines()
		if calm() then
			return
		end
		for _, bar in lines do
			bar.BackgroundTransparency = 0.55
			TweenService:Create(bar, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
		end
	end

	-- Dust: one small emitter per character, at the feet, fired by hand (Emit) on each step.
	local dust = {} -- Player -> { character, emitter, travelled, side }
	local function dustFor(p, character, root)
		local d = dust[p]
		if d and d.character == character and d.emitter.Parent then
			return d
		end
		local att = Instance.new("Attachment")
		att.Name = "HuzzDust"
		att.Position = Vector3.new(0, -2.9, 0)
		att.Parent = root
		local e = Instance.new("ParticleEmitter")
		e.Name = "Dust"
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(236, 222, 200), Color3.fromRGB(200, 186, 166))
		e.LightInfluence = 1
		e.Rate = 0
		e.Lifetime = NumberRange.new(0.35, 0.6)
		e.Speed = NumberRange.new(1.5, 3.5)
		e.SpreadAngle = Vector2.new(70, 70)
		e.Acceleration = Vector3.new(0, 2, 0)
		e.Drag = 4
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.6) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-40, 40)
		e.Parent = att
		d = { character = character, emitter = e, travelled = 0, lastDash = nil }
		dust[p] = d
		return d
	end
	Players.PlayerRemoving:Connect(function(p)
		dust[p] = nil
	end)

	local camera = Workspace.CurrentCamera
	local extra = 0 -- the FOV we've added (eased)
	local myLastDash = nil
	Frame.on(5, function(dt)
		dt = math.clamp(dt, 1 / 240, 1 / 15)
		local now = Workspace:GetServerTimeNow()
		if Workspace.CurrentCamera ~= camera then
			extra = 0 -- (a new camera starts clean: never take our extra off a camera we didn't add it to)
		end
		camera = Workspace.CurrentCamera
		local myRoot = nil

		for _, p in Players:GetPlayers() do
			local character = p.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and inRound(p) and not character:GetAttribute("DownedAt") and camera
				and (camera.CFrame.Position - root.Position).Magnitude < NEAR then
				local d = dustFor(p, character, root)
				local v = root.AssemblyLinearVelocity
				local speed = Vector3.new(v.X, 0, v.Z).Magnitude
				-- a puff each step (half a stride) while running on the ground
				if speed > Run.From and math.abs(v.Y) < 8 then
					d.travelled += speed * dt
					if d.travelled >= Run.Stride / 2 then
						d.travelled = 0
						d.emitter:Emit(2)
						if p == player then
							Sfx.play("step")
						end
					end
				else
					d.travelled = 0
				end
				local dashAt = character:GetAttribute("DashAt")
				if type(dashAt) == "number" and dashAt ~= d.lastDash then
					d.lastDash = dashAt
					if now - dashAt < 0.3 then
						d.emitter:Emit(8)
					end
				end
			end
			if p == player then
				myRoot = root
			end
		end

		-- The camera: only our own, in a round, while the normal camera has the view.
		if not camera then
			return
		end
		local want = 0
		local sprint = 0 -- 0 = walking, 1 = flat out
		local character = player.Character
		local cinematic = player:GetAttribute("HuzzCinematic") == true or camera.CameraType == Enum.CameraType.Scriptable
		if myRoot and not cinematic and not calm() then
			local v = myRoot.AssemblyLinearVelocity
			local speed = Vector3.new(v.X, 0, v.Z).Magnitude
			local h = character and character:FindFirstChildOfClass("Humanoid")
			local cap = (h and h:GetAttribute("HuzzSpeed")) or (h and h.WalkSpeed) or 20
			sprint = math.clamp((speed - Run.From) / math.max(cap - Run.From, 4), 0, 1) ^ 1.4
			want = sprint * SPRINT_FOV
			local dashAt = character and character:GetAttribute("DashAt")
			if type(dashAt) == "number" then
				local age = now - dashAt
				if age >= 0 and age < DASH_TIME then
					want += DASH_FOV * (1 - age / DASH_TIME) ^ 2
				end
				if dashAt ~= myLastDash then
					myLastDash = dashAt
					if age < 0.3 then
						speedLines()
					end
				end
			end
		end
		-- the wind streaks: in from about 70% of top speed, drifting outward on a loop
		streakClock += dt
		local show = math.clamp((sprint - 0.7) / 0.3, 0, 1)
		for _, st in streaks do
			if show <= 0 then
				st.bar.BackgroundTransparency = 1
			else
				local u = (streakClock * 1.6 + st.phase) % 1
				local r = 0.36 + u * 0.16
				st.bar.Position = UDim2.fromScale(0.5 + math.cos(st.angle) * r, 0.5 + math.sin(st.angle) * r)
				-- fade in and out along each pass, so nothing pops
				st.bar.BackgroundTransparency = 1 - show * 0.35 * math.sin(u * math.pi)
			end
		end
		if cinematic then
			-- the intro camera sets its own view: hand back exactly what we added and stay out of its way
			if extra ~= 0 then
				camera.FieldOfView -= extra
				extra = 0
			end
			return
		end
		local k = 1 - math.exp(-dt * (if want > extra then 10 else 4)) -- quick out, gentle back
		local nextExtra = extra + (want - extra) * k
		if math.abs(nextExtra) < 0.01 and want == 0 then
			nextExtra = 0
		end
		camera.FieldOfView += nextExtra - extra
		extra = nextExtra
	end)
end

return M
