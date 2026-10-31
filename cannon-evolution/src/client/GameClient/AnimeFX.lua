--[[
	AnimeFX  (ModuleScript)
	Anime power-up effects on top of the shots (Alex, Oct 31: "crazy cannon shots", Dragon Ball style
	auras). It only listens to the shot remotes and adds effects; the launch itself, its timing and its
	sounds stay in Effects.lua.

	- Training: a power aura on your character that flares, pulses on every shot and grows with your
	  Power level; a charge burst on each level up; crits get an impact frame and a hit-stop.
	- Launch: an impact frame, a burst of radial speed lines, a shockwave at the muzzle, an energy
	  aura on the cannonball and speed streaks across the screen while it cruises.
	- Everything is coloured and layered by the equipped cannon's tier (Basic → Secret): one new
	  channel per tier, not just more particles.

	Kid-safe: at most one flash a second, no shake on Low Graphics, and every emitter lives on an
	Attachment (Effects' Low Graphics switch leaves those alone; this module dims them itself).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local RING = "rbxasset://textures/particles/explosion01_shockwave_main.dds"

-- one look per cannon tier; Rank decides which channels switch on
local TIERS = {
	Basic = { Rank = 1, Color = Color3.fromRGB(80, 200, 255), Core = Color3.fromRGB(235, 250, 255) },
	Rare = { Rank = 2, Color = Color3.fromRGB(40, 110, 255), Core = Color3.fromRGB(200, 235, 255) },
	Epic = { Rank = 3, Color = Color3.fromRGB(175, 80, 255), Core = Color3.fromRGB(240, 210, 255) },
	Legendary = { Rank = 4, Color = Color3.fromRGB(255, 200, 40), Core = Color3.fromRGB(255, 250, 200) },
	Secret = { Rank = 5, Color = Color3.fromRGB(255, 50, 100), Core = Color3.fromRGB(255, 225, 235), Rainbow = true },
}

return function(ctx)
	local Kit, Config, State = ctx.Kit, ctx.Config, ctx.State
	local new = Kit.new
	local player = ctx.Player
	local stations = workspace:WaitForChild("TrainingStations")

	local function lowGraphics()
		local s = State.Data and State.Data.Settings
		return s and s.LowGraphics == true
	end

	local function tierOf(cannonId)
		local info = cannonId and Config.GetCannon(cannonId)
		return TIERS[info and info.Tier or "Basic"] or TIERS.Basic
	end
	local function myTier()
		return tierOf(State.Data and State.Data.EquippedCannon)
	end

	-- kid-safe: at most one bright flash a second, whatever asks for it
	local lastFlash = -10
	local function mayFlash()
		if os.clock() - lastFlash < 1 then
			return false
		end
		lastFlash = os.clock()
		return true
	end

	-----------------------------------------------------------------------
	-- Camera: shake and hit-stop, layered on after the camera has moved.
	-- Effects sets the flight camera on Heartbeat and the default camera
	-- sets it at Camera priority, so an offset added here never piles up;
	-- if nobody moved the camera since our last write, we undo it first.
	-----------------------------------------------------------------------
	local shakeAmp, shakeEnd, shakeLen = 0, 0, 1
	local freezeUntil, frozenAt = 0, nil
	local lastWritten, lastBase = nil, nil
	local function shake(amount, length)
		if lowGraphics() then
			return
		end
		local now = os.clock()
		local left = math.max(shakeEnd - now, 0) / shakeLen * shakeAmp
		if amount >= left then
			shakeAmp, shakeLen, shakeEnd = amount, length, now + length
		end
	end
	-- hit-stop: the camera and the aura hold still for a few frames, then everything snaps on
	local frozenEmitters = {}
	local function hitStop(length)
		local cam = workspace.CurrentCamera
		freezeUntil = os.clock() + length
		frozenAt = cam.CFrame
		for _, pe in ipairs(frozenEmitters) do
			if pe.Parent then
				pe.TimeScale = 0
			end
		end
		task.delay(length, function()
			for _, pe in ipairs(frozenEmitters) do
				pe.TimeScale = 1
			end
		end)
	end
	RunService:BindToRenderStep("AnimeFXCamera", Enum.RenderPriority.Camera.Value + 1, function()
		local cam = workspace.CurrentCamera
		if lastWritten and cam.CFrame == lastWritten then
			cam.CFrame = lastBase
		end
		lastWritten = nil
		local now = os.clock()
		local base = cam.CFrame
		local out = base
		if now < freezeUntil and frozenAt then
			out = frozenAt
		elseif now < shakeEnd then
			local a = (shakeEnd - now) / shakeLen
			local amp = shakeAmp * a * a
			out = base * CFrame.new((math.random() - 0.5) * amp, (math.random() - 0.5) * amp, 0)
				* CFrame.Angles(0, 0, (math.random() - 0.5) * amp * 0.03)
		end
		if out ~= base then
			cam.CFrame = out
			lastWritten, lastBase = out, base
		end
	end)

	-----------------------------------------------------------------------
	-- Screen layer: impact frames and speed lines (under the HUD)
	-----------------------------------------------------------------------
	local gui = new("ScreenGui", { Name = "AnimeFX", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = -1, Parent = player:WaitForChild("PlayerGui") })
	local grade = new("ColorCorrectionEffect", { Name = "AnimeImpact", Enabled = false, Parent = Lighting })

	-- the impact frame: two frames of hard black-and-white ink with the subject in silhouette, then
	-- colour floods back. Reads as a manga panel, not a strobe (one per second at most)
	local function impactFrame(subject, tier, strong)
		if lowGraphics() or not mayFlash() then
			return false
		end
		grade.Enabled = true
		grade.Saturation, grade.Contrast, grade.Brightness = -1, strong and 2.5 or 1.5, -0.05
		grade.TintColor = Color3.new(1, 1, 1)
		local hl
		if subject and subject.Parent then
			hl = new("Highlight", {
				FillColor = Color3.new(0, 0, 0), FillTransparency = 0, OutlineColor = Color3.new(1, 1, 1), OutlineTransparency = 0,
				DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Adornee = subject, Parent = gui,
			})
		end
		task.delay(0.07, function()
			if hl then
				hl.FillColor, hl.FillTransparency, hl.OutlineColor = tier.Core, 0.2, tier.Color
			end
			grade.Saturation, grade.Contrast, grade.Brightness = 0.6, 0.4, 0.05
			grade.TintColor = tier.Core
			local back = TweenService:Create(grade, TweenInfo.new(0.22, Enum.EasingStyle.Quad), {
				Saturation = 0, Contrast = 0, Brightness = 0, TintColor = Color3.new(1, 1, 1),
			})
			back.Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed then
					grade.Enabled = false
				end
			end)
			back:Play()
			if hl then
				TweenService:Create(hl, TweenInfo.new(0.25), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
				Debris:AddItem(hl, 0.3)
			end
		end)
		return true
	end

	-- a pool of thin white strokes for the radial burst and the flight streaks
	local LINES = 40
	local lines = {}
	for i = 1, LINES do
		lines[i] = new("Frame", {
			Name = "Line", AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 1, Visible = false, Parent = gui,
		})
	end
	local lineMode, lineConn = nil, nil
	local function stopLines()
		if lineConn then
			lineConn:Disconnect()
			lineConn = nil
		end
		lineMode = nil
		for _, l in ipairs(lines) do
			l.Visible = false
		end
	end

	-- anime focus lines: strokes rushing out from the screen point of the shot, gone in a quarter second
	local function radialBurst(screenPos, tier)
		if lineMode == "streaks" then
			return
		end
		stopLines()
		lineMode = "burst"
		local view = workspace.CurrentCamera.ViewportSize
		local reach = view.Magnitude * 0.6
		local count = math.min(18 + tier.Rank * 4, LINES)
		local state = {}
		for i = 1, count do
			local a = (i / count + math.random() * 0.4 / count) * math.pi * 2
			state[i] = { A = a, R = reach * (0.25 + math.random() * 0.2), Len = reach * (0.3 + math.random() * 0.35), W = 2 + math.random() * (2 + tier.Rank) }
			local l = lines[i]
			l.Rotation = math.deg(a)
			l.BackgroundColor3 = i % 3 == 0 and tier.Color or Color3.new(1, 1, 1)
			l.Visible = true
		end
		local t0 = os.clock()
		lineConn = RunService.RenderStepped:Connect(function()
			local k = (os.clock() - t0) / 0.28
			if k >= 1 then
				stopLines()
				return
			end
			for i = 1, count do
				local s, l = state[i], lines[i]
				local r = s.R + reach * 0.5 * k
				local c = Vector2.new(math.cos(s.A), math.sin(s.A))
				local p = screenPos + c * (r + s.Len / 2)
				l.Position = UDim2.fromOffset(p.X, p.Y)
				l.Size = UDim2.fromOffset(s.Len * (1 - k * 0.5), s.W * (1 - k))
				l.BackgroundTransparency = 0.1 + k * 0.9
			end
		end)
	end

	-- speed streaks across the screen, running against the ball's motion, while it cruises
	local function flightStreaks(ball, duration, tier)
		stopLines()
		lineMode = "streaks"
		local cam = workspace.CurrentCamera
		local view = cam.ViewportSize
		local count = math.min(10 + tier.Rank * 3, LINES)
		local state = {}
		local flow = Vector2.new(1, 0) -- which way the ball moves on screen
		local function respawn(s, anywhere)
			local p = Vector2.new(math.random() * view.X, math.random() * view.Y)
			-- a new streak enters from the side the ball is heading to
			s.P = anywhere and p or p + flow * view.Magnitude * 0.6
			s.Len = 80 + math.random() * 260
			s.W = 1 + math.random() * 2.5
			s.Speed = 2200 + math.random() * 1800
		end
		for i = 1, count do
			state[i] = {}
			respawn(state[i], true)
			lines[i].BackgroundColor3 = i % 4 == 0 and tier.Color or Color3.new(1, 1, 1)
			lines[i].Visible = true
		end
		local t0 = os.clock()
		lineConn = RunService.RenderStepped:Connect(function(dt)
			local t = os.clock() - t0
			local u = t / duration
			if u >= 0.9 or not ball.Parent then
				stopLines()
				return
			end
			-- strongest right after the shot, settling to a light rush, then gone as the ball slows (80%)
			local strength = math.max(0, 1 - t / 1.2) * 0.6 + 0.25
			if u > 0.7 then
				strength *= math.max(0, (0.9 - u) / 0.2)
			end
			local a = cam:WorldToViewportPoint(ball.Position)
			local b = cam:WorldToViewportPoint(ball.Position + Config.LAUNCH_DIRECTION.Unit * 10)
			local f = Vector2.new(b.X - a.X, b.Y - a.Y)
			flow = f.Magnitude > 1 and f.Unit or flow
			local rot = math.deg(math.atan2(flow.Y, flow.X))
			for i = 1, count do
				local s, l = state[i], lines[i]
				s.P -= flow * s.Speed * dt
				local c = s.P - view / 2
				if c:Dot(flow) < -view.Magnitude * 0.6 then
					respawn(s, false)
				end
				l.Rotation = rot
				l.Position = UDim2.fromOffset(s.P.X, s.P.Y)
				l.Size = UDim2.fromOffset(s.Len, s.W)
				l.BackgroundTransparency = 1 - 0.55 * strength
			end
		end)
	end

	-----------------------------------------------------------------------
	-- World pieces
	-----------------------------------------------------------------------
	local function emitter(parent, props)
		local pe = new("ParticleEmitter", props)
		pe.Parent = parent
		return pe
	end

	-- a flat ring that blows out and fades; the anime shockwave
	local function ringAt(cf, color, from, to, life, thick)
		local ring = new("Part", {
			Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = color, Transparency = 0.15,
			Size = Vector3.new(thick or 0.25, from, from), CFrame = cf,
			Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Parent = workspace,
		})
		TweenService:Create(ring, TweenInfo.new(life, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.05, to, to), Transparency = 1,
		}):Play()
		Debris:AddItem(ring, life + 0.05)
		return ring
	end

	-- energy crackle: a jagged bolt of thin neon segments, gone in a blink
	local function bolt(from, to, color, width)
		local pieces = 4
		local prev = from
		local folder = new("Folder", { Name = "Bolt", Parent = workspace })
		for i = 1, pieces do
			local p = i == pieces and to or from:Lerp(to, i / pieces) + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * (from - to).Magnitude * 0.35
			local len = (p - prev).Magnitude
			new("Part", {
				Material = Enum.Material.Neon, Color = color, Size = Vector3.new(width, width, len),
				CFrame = CFrame.lookAt((prev + p) / 2, p),
				Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Parent = folder,
			})
			prev = p
		end
		Debris:AddItem(folder, 0.07)
	end

	-- rocks burst up in a ring round a point, coloured like the floor, then sink away
	local floorRay = RaycastParams.new()
	floorRay.FilterType = Enum.RaycastFilterType.Exclude
	local function crater(pos, count)
		if lowGraphics() then
			return
		end
		floorRay.FilterDescendantsInstances = { player.Character }
		local hit = workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -8, 0), floorRay)
		if not hit then
			return
		end
		local color = hit.Instance.Color
		local folder = new("Folder", { Name = "Crater", Parent = workspace })
		for i = 1, count do
			local a = (i / count) * math.pi * 2 + math.random() * 0.3
			local size = Vector3.new(1.2, 1, 1.2) * (0.8 + math.random() * 0.7)
			local at = hit.Position + Vector3.new(math.cos(a), 0, math.sin(a)) * (3 + math.random())
			local up = CFrame.lookAt(at, at + Vector3.new(math.cos(a), 0, math.sin(a))) * CFrame.Angles(math.rad(-25 - math.random() * 20), 0, 0)
			local rock = new("Part", {
				Size = size, Color = color:Lerp(Color3.new(0, 0, 0), math.random() * 0.2), Material = Enum.Material.Slate,
				CFrame = up - Vector3.new(0, size.Y, 0), Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Parent = folder,
			})
			TweenService:Create(rock, TweenInfo.new(0.12, Enum.EasingStyle.Back), { CFrame = up }):Play()
			task.delay(2.5, function()
				TweenService:Create(rock, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = up - Vector3.new(0, size.Y * 1.5, 0) }):Play()
			end)
		end
		Debris:AddItem(folder, 3.5)
	end

	-----------------------------------------------------------------------
	-- The power aura (one rig per character, reused). Layers from vault
	-- Build Playbooks 15 §3: shell, flames, core, streaks, ground, crackle,
	-- outline, light. Each step up adds one channel.
	-- The flames and shell are neon / force-field shapes, not particles: the
	-- built-in fire texture is a dim smoky blot that vanishes on this bright
	-- map (Studio check, Oct 31). Shapes over particles, as the hits do it.
	-----------------------------------------------------------------------
	local auras = {} -- [character] = rig

	-- one flame tongue: a neon teardrop that shoots up along `up`, stretches thin and fades
	local fx = new("Folder", { Name = "AnimeFX", Parent = workspace })
	local function tongue(base, up, out, height, width, color, alpha, life)
		local p = new("Part", {
			Material = Enum.Material.Neon, Color = color, Transparency = alpha, Size = Vector3.new(width, height * 0.25, width),
			Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
		})
		new("SpecialMesh", { MeshType = Enum.MeshType.Sphere, Parent = p })
		-- stand it along `up`, leaning a little outward
		local side = CFrame.lookAt(base, base + out, up).XVector
		local cf = CFrame.fromMatrix(base, side, up.Unit:Lerp(out.Unit, 0.12).Unit)
		p.CFrame = cf
		p.Parent = fx
		TweenService:Create(p, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(width * 0.3, height, width * 0.3), CFrame = cf + cf.YVector * height * 0.55,
		}):Play()
		TweenService:Create(p, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
		Debris:AddItem(p, life + 0.05)
	end

	-- a ring of tongues round a body: outer ones in the tier colour, every third a white-hot core
	local function flare(rig, count)
		local root = rig.Root
		if not root.Parent then
			return
		end
		local tier, grow = rig.Tier, rig.Grow or 1
		local at = root.Position
		for _ = 1, count do
			rig.Count = (rig.Count or 0) + 1
			local core = rig.Step >= 0.2 and rig.Count % 3 == 0
			local a = math.random() * math.pi * 2
			local out = Vector3.new(math.cos(a), 0, math.sin(a))
			local r = core and 0.8 + math.random() * 0.4 or 1.4 + math.random() * 0.6
			local base = at + out * r * grow + Vector3.new(0, -2.7 + math.random() * 1.6, 0)
			local color = tier.Rainbow and Color3.fromHSV(math.random(), 0.65, 1) or tier.Color
			tongue(base, Vector3.yAxis, out, (core and 2.5 or 3.6) * grow + math.random() * 2.5, core and 0.7 or 1.1 * grow,
				core and tier.Core or color, core and 0.25 or 0.1, 0.4 + math.random() * 0.15)
		end
	end

	local function buildAura(character)
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then
			return nil
		end
		local rig = { Character = character, Root = root, Emitters = {}, Rate = 0, Debt = 0 }
		local feet = new("Attachment", { Name = "AnimeAuraFeet", Position = Vector3.new(0, -2.6, 0), Parent = root })
		local core = new("Attachment", { Name = "AnimeAuraCore", Position = Vector3.new(0, 0.3, 0), Parent = root })
		rig.Feet, rig.Core = feet, core
		local function welded(part, offset)
			part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.Massless, part.CastShadow = false, false, false, false, true, false
			part.CFrame = root.CFrame * offset
			new("WeldConstraint", { Part0 = root, Part1 = part, Parent = part })
			part.Parent = character
			return part
		end
		-- shell: the egg of energy round the body (force-field material shimmers on its own)
		rig.Shell = welded(new("Part", { Name = "AnimeAuraShell", Shape = Enum.PartType.Ball, Material = Enum.Material.ForceField, Size = Vector3.one * 5.5, Transparency = 1 }), CFrame.new(0, 0.2, 0))
		rig.ShellMesh = new("SpecialMesh", { MeshType = Enum.MeshType.Sphere, Scale = Vector3.new(1, 1.45, 1), Parent = rig.Shell })
		-- ground: a glowing disc under the feet
		rig.Disc = welded(new("Part", { Name = "AnimeAuraDisc", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Size = Vector3.new(0.1, 6, 6), Transparency = 1 }),
			CFrame.new(0, -2.95, 0) * CFrame.Angles(0, 0, math.rad(90)))
		-- streaks: thin sparks shooting straight up
		rig.Streaks = emitter(feet, {
			Texture = SPARK, LightEmission = 1, LightInfluence = 0, Rate = 0, Brightness = 2,
			Orientation = Enum.ParticleOrientation.VelocityParallel, Squash = NumberSequence.new(2.5),
			Size = NumberSequence.new(0.5, 0), Lifetime = NumberRange.new(0.25, 0.45), Speed = NumberRange.new(10, 16),
			SpreadAngle = Vector2.new(25, 25), EmissionDirection = Enum.NormalId.Top,
		})
		-- dust pushed out along the floor
		rig.Dust = emitter(feet, {
			Texture = SMOKE, LightEmission = 0, LightInfluence = 0.8, Rate = 0, Color = ColorSequence.new(Color3.fromRGB(240, 235, 225)),
			Size = NumberSequence.new(1, 3.5), Transparency = NumberSequence.new(0.35, 1), Lifetime = NumberRange.new(0.5, 0.8),
			Speed = NumberRange.new(8, 12), SpreadAngle = Vector2.new(85, 5), EmissionDirection = Enum.NormalId.Front,
			Acceleration = Vector3.new(0, 2, 0), Drag = 3,
		})
		rig.Light = new("PointLight", { Brightness = 0, Range = 12, Shadows = false, Parent = core })
		if character == player.Character then
			-- the outline: local player only (Roblox draws at most 31 Highlights at once)
			rig.Highlight = new("Highlight", {
				FillTransparency = 1, OutlineTransparency = 1, DepthMode = Enum.HighlightDepthMode.Occluded, Adornee = character, Parent = character,
			})
		end
		for _, pe in ipairs({ rig.Streaks, rig.Dust }) do
			table.insert(rig.Emitters, pe)
			table.insert(frozenEmitters, pe)
		end
		auras[character] = rig
		character.Destroying:Connect(function()
			auras[character] = nil
		end)
		return rig
	end

	-- the flames burn at each rig's rate; the shell breathes
	RunService.Heartbeat:Connect(function(dt)
		if os.clock() < freezeUntil then
			return -- hit-stop: nothing new while the frame holds
		end
		for _, rig in pairs(auras) do
			if rig.Rate > 0 and rig.Root.Parent then
				rig.Debt += rig.Rate * dt
				local n = math.floor(rig.Debt)
				if n > 0 then
					rig.Debt -= n
					flare(rig, math.min(n, 6))
				end
				local b = 0.5 + 0.5 * math.sin(os.clock() * 9)
				rig.Shell.Transparency = rig.ShellAlpha + 0.12 * b
				local s = (rig.Grow or 1) * (1 + 0.04 * b)
				rig.ShellMesh.Scale = Vector3.new(s, 1.45 * s, s)
			elseif rig.Shell.Transparency < 1 then
				rig.Shell.Transparency = 1
			end
		end
	end)

	local function auraFor(character)
		if not character or not character.Parent then
			return nil
		end
		local rig = auras[character]
		if rig and rig.Root.Parent then
			return rig
		end
		return buildAura(character)
	end

	-- the step on the ladder: the cannon's tier, or how far you've trained this rebirth if that's higher
	local function stepOf(tier, power)
		return math.max((tier.Rank - 1) / 4, power * 0.6)
	end

	-- set the aura's look: tier colours, and how hard it burns (0 = off, 1 = full power)
	local function setAura(rig, tier, power, full)
		local low = lowGraphics()
		local on = power > 0
		local scale = (full and 1 or 0.5) * (low and 0.4 or 1)
		local step = stepOf(tier, power)
		rig.Tier, rig.Power, rig.Step = tier, power, step
		-- the flames grow 10-20% a step and with your power
		rig.Grow = 1 + 0.25 * step + 0.15 * power
		rig.Rate = on and (16 + 30 * power + 10 * step) * scale or 0
		rig.ShellAlpha = 0.55 - 0.25 * power
		rig.Shell.Color = tier.Color
		rig.Disc.Color = tier.Color
		rig.Disc.Transparency = on and full and step >= 0.5 and 0.6 or 1
		rig.Disc.Size = Vector3.new(0.1, 6 * rig.Grow, 6 * rig.Grow)
		rig.Streaks.Color = ColorSequence.new(tier.Core)
		rig.Streaks.Rate = on and step >= 0.4 and (8 + 10 * power) * scale or 0
		rig.Dust.Rate = on and full and step >= 0.5 and 3 + 4 * power or 0
		rig.Light.Color = tier.Color
		rig.Light.Brightness = on and full and (0.8 + 1.4 * power) or 0
		if rig.Highlight then
			rig.Highlight.OutlineColor, rig.Highlight.FillColor = tier.Color, tier.Core
			rig.Highlight.OutlineTransparency = on and step >= 0.75 and 0.35 or 1
		end
	end

	-- every shot: the aura flares and the body glows for a moment
	local function auraPulse(rig, big)
		if not rig or not rig.Tier then
			return
		end
		local tier = rig.Tier
		flare(rig, big and 16 or 6)
		if rig.Step >= 0.4 then
			rig.Streaks:Emit(big and 20 or 5)
		end
		local hl = rig.Highlight
		if hl then
			hl.FillTransparency = big and 0.55 or 0.8
			TweenService:Create(hl, TweenInfo.new(big and 0.35 or 0.2, Enum.EasingStyle.Quad), { FillTransparency = 1 }):Play()
		end
		local light = rig.Light
		local base = light.Brightness
		light.Brightness = base + (big and 3 or 1.2)
		TweenService:Create(light, TweenInfo.new(0.25), { Brightness = base }):Play()
		-- crackle (high steps): a couple of bolts round the body
		if rig.Step >= 0.5 and not lowGraphics() then
			local at = rig.Root.Position
			for _ = 1, big and 3 or 1 do
				local a = math.random() * math.pi * 2
				local p0 = at + Vector3.new(math.cos(a) * 1.6, -2 + math.random() * 2, math.sin(a) * 1.6)
				local p1 = p0 + Vector3.new((math.random() - 0.5) * 2, 1.5 + math.random() * 2, (math.random() - 0.5) * 2)
				bolt(p0, p1, tier.Rainbow and Color3.fromHSV(math.random(), 0.6, 1) or tier.Core, 0.12)
			end
		end
	end

	-- the charge burst on a level up: a ring along the floor, a tall flare, a little rumble
	local lastBurst = 0
	local function chargeBurst(rig, final)
		if not rig or not rig.Tier or os.clock() - lastBurst < 0.9 then
			return
		end
		lastBurst = os.clock()
		local tier = rig.Tier
		auraPulse(rig, true)
		local feet = rig.Feet.WorldPosition
		ringAt(CFrame.new(feet + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), tier.Color, 2, final and 26 or 14, final and 0.55 or 0.4)
		if final or tier.Rank >= 3 then
			task.delay(0.08, function()
				ringAt(CFrame.new(feet + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90)), tier.Core, 1.5, final and 18 or 9, 0.35, 0.15)
			end)
		end
		rig.Dust:Emit(final and 24 or 10)
		shake(final and 0.6 or 0.18, final and 0.4 or 0.2)
		if final then
			crater(feet, 10)
			impactFrame(rig.Character, tier, true)
			hitStop(0.06)
		end
	end

	-----------------------------------------------------------------------
	-- Training: my aura burns while I train and grows with my level
	-----------------------------------------------------------------------
	local training = nil
	local lastLevel = nil
	local function myPower()
		local data = State.Data
		if not data then
			return 0, 1
		end
		local level = Config.PowerLevel(data)
		return (level - 1) / (Config.MAX_LEVEL - 1), level
	end
	local function refreshMine()
		local rig = auraFor(player.Character)
		if not rig then
			return
		end
		if training then
			setAura(rig, myTier(), math.max(myPower(), 0.05), true)
		else
			setAura(rig, myTier(), 0, true)
		end
	end
	Remotes.TrainingState.OnClientEvent:Connect(function(stationId)
		local was = training
		training = stationId
		refreshMine()
		if stationId and not was then
			chargeBurst(auraFor(player.Character), false) -- powering up as you step on
		end
	end)
	State.Changed:Connect(function()
		local data = State.Data
		if not data then
			return
		end
		local _, level = myPower()
		if training and lastLevel and level > lastLevel then
			chargeBurst(auraFor(player.Character), level >= Config.MAX_LEVEL)
		end
		lastLevel = level
		refreshMine()
	end)
	-- the crackle at the top steps: about four arcs a second while you train
	task.spawn(function()
		while true do
			task.wait(0.22 + math.random() * 0.1)
			local rig = training and auras[player.Character]
			if rig and rig.Step and rig.Step >= 0.75 and rig.Power > 0 and not lowGraphics() then
				local at = rig.Root.Position
				local a = math.random() * math.pi * 2
				local p0 = at + Vector3.new(math.cos(a) * 1.4, -2.2 + math.random() * 2.5, math.sin(a) * 1.4)
				local p1 = p0 + Vector3.new((math.random() - 0.5) * 1.5, 1.2 + math.random() * 1.8, (math.random() - 0.5) * 1.5)
				bolt(p0, p1, rig.Tier.Rainbow and Color3.fromHSV(math.random(), 0.6, 1) or rig.Tier.Core, 0.1)
			end
		end
	end)
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		refreshMine()
	end)

	-- other players' auras flare while they keep shooting, at half strength, and only up close
	local othersUntil = {}
	Remotes.TrainingShot.OnClientEvent:Connect(function(shooter, stationId, gain, crit)
		local isMine = shooter == player
		if isMine then
			local rig = auraFor(player.Character)
			auraPulse(rig, crit)
			if crit then
				local station = stations:FindFirstChild("Station_" .. stationId)
				local center = station and station:FindFirstChild("Target") and station.Target:FindFirstChild("Center")
				-- the crit lands 0.35 s later (Effects' ball flight): freeze-frame on the hit
				task.delay(0.35, function()
					if impactFrame(center and center.Parent or player.Character, rig and rig.Tier or myTier(), false) then
						hitStop(0.07)
					end
					shake(0.35, 0.25)
					if center then
						local cf = center.CFrame * CFrame.new(0, 0, -0.5) * CFrame.Angles(0, math.rad(90), 0)
						ringAt(cf, (rig and rig.Tier or myTier()).Core, 2, 12, 0.3)
					end
				end)
			end
			return
		end
		local character = shooter and shooter.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or (workspace.CurrentCamera.CFrame.Position - root.Position).Magnitude > 80 then
			return
		end
		local rig = auraFor(character)
		if not rig then
			return
		end
		setAura(rig, tierOf(shooter:GetAttribute("Cannon")), 0.4, false)
		auraPulse(rig, false)
		othersUntil[character] = os.clock() + 2
		task.delay(2.1, function()
			if othersUntil[character] and os.clock() >= othersUntil[character] and auras[character] then
				othersUntil[character] = nil
				setAura(auras[character], rig.Tier, 0, false)
			end
		end)
	end)

	-----------------------------------------------------------------------
	-- Launch: the big moment. Nothing here waits: it all runs alongside
	-- Effects' launch on the same frame.
	-----------------------------------------------------------------------
	local function findBall(origin)
		local best, bestD = nil, math.huge
		for _, c in ipairs(workspace:GetChildren()) do
			if c.Name == "Cannonball" and not c:GetAttribute("AnimeFX") then
				local d = (c.Position - origin).Magnitude
				if d < bestD then
					best, bestD = c, d
				end
			end
		end
		if best then
			best:SetAttribute("AnimeFX", true)
		end
		return best
	end

	-- the energy that wraps the ball in flight
	local function ballAura(ball, tier, mine, duration)
		local att = new("Attachment", { Name = "AnimeBallAura", Parent = ball })
		local low = lowGraphics()
		local scale = (mine and 1 or 0.5) * (low and 0.4 or 1)
		-- an egg of energy round the ball, and flame tongues streaming back off it
		local size = 4 + tier.Rank * 0.6
		local shell = new("Part", {
			Name = "AnimeBallShell", Shape = Enum.PartType.Ball, Material = Enum.Material.ForceField, Color = tier.Color,
			Size = Vector3.one * size, CFrame = ball.CFrame, Transparency = 0,
			Anchored = false, CanCollide = false, CanQuery = false, CanTouch = false, Massless = true, CastShadow = false,
		})
		new("SpecialMesh", { MeshType = Enum.MeshType.Sphere, Scale = Vector3.new(1, 1, 1), Parent = shell })
		new("WeldConstraint", { Part0 = ball, Part1 = shell, Parent = shell })
		shell.Parent = ball
		local dir = Config.LAUNCH_DIRECTION.Unit
		-- the comet head: flame spikes that ride with the ball and flicker, pointing back along the shot
		local spikes = {}
		for i = 1, mine and 7 or 4 do
			local core = i % 3 == 0
			local p = new("Part", {
				Material = Enum.Material.Neon, Color = core and tier.Core or tier.Color, Transparency = core and 0.2 or 0.1,
				Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Parent = fx,
			})
			new("SpecialMesh", { MeshType = Enum.MeshType.Sphere, Parent = p })
			local j = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * (core and 0.25 or 0.8)
			spikes[i] = { Part = p, Jitter = j, Core = core, Phase = math.random() * 6 }
		end
		local rate, debt, t0 = (16 + tier.Rank * 4) * scale, 0, os.clock()
		local conn
		conn = RunService.Heartbeat:Connect(function(dt)
			local t = os.clock() - t0
			if not ball.Parent or t > duration then
				conn:Disconnect()
				for _, sp in ipairs(spikes) do
					TweenService:Create(sp.Part, TweenInfo.new(0.2), { Transparency = 1 }):Play()
					Debris:AddItem(sp.Part, 0.25)
				end
				return
			end
			local fade = t > duration * 0.8 and 0.3 or 1 -- dies down as the ball slows and skips out
			local at = ball.Position
			for i, sp in ipairs(spikes) do
				local d = (-dir + sp.Jitter + Vector3.new(0, 0.15, 0)).Unit
				local len = size * fade * ((sp.Core and 1.1 or 1.7) + 0.5 * math.sin(t * 26 + sp.Phase) + math.random() * 0.3)
				local w = size * (sp.Core and 0.28 or 0.4)
				sp.Part.Size = Vector3.new(w, len, w)
				sp.Part.CFrame = CFrame.fromMatrix(at + d * len * 0.38, d:Cross(Vector3.yAxis).Unit, d)
				sp.Part.Transparency = (sp.Core and 0.2 or 0.1) + (1 - fade) * 0.6
			end
			-- and loose tongues peeling off behind it
			debt += rate * fade * dt
			while debt >= 1 do
				debt -= 1
				local jitter = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * size * 0.5
				local color = tier.Rainbow and Color3.fromHSV(math.random(), 0.65, 1) or (math.random() < 0.3 and tier.Core or tier.Color)
				tongue(at + jitter, -dir + Vector3.new(0, 0.25, 0), Vector3.yAxis, size * (0.9 + math.random() * 0.8), size * 0.35, color, 0.15, 0.3)
			end
		end)
		task.delay(duration * 0.8, function()
			TweenService:Create(shell, TweenInfo.new(duration * 0.2), { Transparency = 1 }):Play()
		end)
		local list = {}
		if tier.Rank >= 2 then
			table.insert(list, emitter(att, {
				Texture = SPARK, Color = ColorSequence.new(tier.Core), LightEmission = 1, LightInfluence = 0,
				Size = NumberSequence.new(0.6, 0), Lifetime = NumberRange.new(0.4, 0.7), Speed = NumberRange.new(2, 6),
				SpreadAngle = Vector2.new(180, 180), Rate = 25 * scale,
			}))
		end
		-- crackle round the ball (Epic+), a few times a second
		if tier.Rank >= 3 and mine and not low then
			task.spawn(function()
				local t0 = os.clock()
				while ball.Parent and os.clock() - t0 < duration * 0.85 do
					local p = ball.Position
					local off = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5).Unit * 2.4
					bolt(p + off * 0.4, p + off + Vector3.new(0, 0.5, 0) - Config.LAUNCH_DIRECTION.Unit * 2, tier.Rainbow and Color3.fromHSV(math.random(), 0.6, 1) or tier.Core, 0.15)
					task.wait(0.12 + math.random() * 0.12)
				end
			end)
		end
		-- the ball's aura dies down as it slows and skips out
		task.delay(duration * 0.8, function()
			for _, pe in ipairs(list) do
				pe.Rate *= 0.3
			end
		end)
		task.delay(duration, function()
			for _, pe in ipairs(list) do
				pe.Enabled = false
			end
		end)
	end

	-- the blast at the muzzle: rings along the shot, a burst of flame and light
	local function muzzleBlast(at, tier)
		local dir = Config.LAUNCH_DIRECTION.Unit
		local face = CFrame.lookAt(at, at + dir) * CFrame.Angles(0, math.rad(90), 0)
		ringAt(face + dir * 1, Color3.new(1, 1, 1), 3, 16, 0.3, 0.35)
		ringAt(face + dir * 4, tier.Color, 2, 12, 0.38, 0.25)
		if tier.Rank >= 3 then
			task.delay(0.06, function()
				ringAt(face + dir * 8, tier.Core, 1.5, 10, 0.32, 0.2)
			end)
		end
		-- a ground ring round the cannon (Rare+)
		if tier.Rank >= 2 then
			local ground = Vector3.new(at.X, at.Y - 6, at.Z)
			ringAt(CFrame.new(ground) * CFrame.Angles(0, 0, math.rad(90)), tier.Color, 4, 30, 0.5, 0.2)
		end
		-- a spray of flame tongues blasting out along the shot
		for i = 1, 10 + tier.Rank * 3 do
			local spread = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 0.7
			local color = tier.Rainbow and Color3.fromHSV(math.random(), 0.65, 1) or (i % 3 == 0 and tier.Core or tier.Color)
			tongue(at + spread, (dir + spread).Unit, Vector3.yAxis, 6 + math.random() * 5, 1.4, color, 0.1, 0.22 + math.random() * 0.1)
		end
		local att = new("Attachment", { WorldPosition = at, Parent = workspace.Terrain })
		att.CFrame = CFrame.lookAt(at, at - dir) -- Front is -Z: face the shot
		local rays = emitter(att, {
			Texture = RING, Color = ColorSequence.new(tier.Core), LightEmission = 0.8, LightInfluence = 0, Enabled = false,
			Orientation = Enum.ParticleOrientation.VelocityPerpendicular, Size = NumberSequence.new(2, 12),
			Transparency = NumberSequence.new(0.2, 1), Lifetime = NumberRange.new(0.35), Speed = NumberRange.new(0.1), EmissionDirection = Enum.NormalId.Front,
		})
		rays:Emit(1)
		new("PointLight", { Color = tier.Color, Brightness = 4, Range = 24, Shadows = false, Parent = att })
		TweenService:Create(att:FindFirstChildOfClass("PointLight"), TweenInfo.new(0.3), { Brightness = 0 }):Play()
		Debris:AddItem(att, 1)
	end

	Remotes.LaunchPlayer.OnClientEvent:Connect(function(owner, origin, distance, duration, cash, rareId)
		local mine = owner == player
		local settings = State.Data and State.Data.Settings
		if not mine and settings and settings.ShowPlayers == false then
			return
		end
		local tier = mine and myTier() or tierOf(owner:GetAttribute("Cannon"))
		local rare = rareId and Config.GetRareShot(rareId)
		if rare and rare.Id == "Mega" then
			tier = TIERS.Secret
		end
		-- Effects makes the ball in its own handler; pick it up on the next frame
		task.defer(function()
			local myCannon = mine and workspace:FindFirstChild("MyCannon")
			local ball = findBall(origin)
			local at = ball and ball.Position or origin
			if ball then
				ballAura(ball, tier, mine, duration)
			end
			if not mine then
				return
			end
			muzzleBlast(at, tier)
			local cam = workspace.CurrentCamera
			local sp = cam:WorldToViewportPoint(at)
			-- the fire frame: ink frame on the cannon, focus lines, a kick of the lens
			impactFrame(myCannon or ball, tier, tier.Rank >= 3 or rare ~= nil)
			radialBurst(Vector2.new(sp.X, sp.Y), tier)
			shake(0.35 + tier.Rank * 0.15, 0.3 + tier.Rank * 0.03)
			local rig = auraFor(player.Character)
			if rig then
				-- the character powers up with the shot, then calms down
				setAura(rig, tier, 1, true)
				auraPulse(rig, true)
				task.delay(0.8, refreshMine)
			end
			if ball then
				task.delay(0.28, function()
					if ball.Parent then
						flightStreaks(ball, duration, tier)
					end
				end)
			end
		end)
	end)

	-- Low Graphics changed: re-apply the aura
	local lastLow = nil
	State.Changed:Connect(function()
		local low = lowGraphics()
		if low ~= lastLow then
			lastLow = low
			refreshMine()
		end
	end)
end
