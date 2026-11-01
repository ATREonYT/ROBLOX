--[[
	AnimeFX  (ModuleScript)
	The rare shots (Alex, Oct 31): normal shots stay clean, like Stone Skipping's; the anime effects
	and cutscenes only play when the server rolls a rare shot (vault notes 15-17: quiet normal
	shots, loud rare shots, each tier adds a new kind of layer).

	- MYTHIC (1 in 100): letterbox, title card, your aura and the cannon's aura pump up, energy
	  streams from you into the cannon, you roar, the cannon charges, then the crazy shot.
	- SECRET (1 in 1,000): the sky turns gold, the camera swoops up to the big golden Grand Cannon
	  on the crag, lightning and god rays hit it, it charges and the ball leaves from there.
	- DIVINE (1 in 100,000): the sky dims, the heavens open, a column of light comes down onto your
	  cannon, feathers fall, it grows wings and a halo and turns white and gold, then fires.

	The server fires RareShot first and waits the cutscene's length before LaunchPlayer, so the
	flight in Effects.lua starts as the cutscene hands the camera back. Effects asks
	ctx.RareMuzzle(rareId) where a Secret ball starts (the Grand Cannon's bore).

	Kid-safe: one impact frame per shot (at most one flash a second), shake and impact frames off on
	Low Graphics, the real tier colour from the first frame, the odds always on the card, and the
	camera is always handed back (also when a second shot or a respawn cuts in).
	Textures: our own (hood/art/vfx and the kit's make_textures.py, uploaded Oct 31) plus the effects from Alex's
	VFX pack (RareFXPack: charge-ups, fire aura, lightning, explosion, shockwave, holy beams, stars).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local TEX = {
	CelFlame = "rbxassetid://71750329568414", -- 4x4 Loop
	CelPuff = "rbxassetid://119591733279212", -- 4x4 OneShot
	Shockwave = "rbxassetid://131585002839496", -- 4x4 OneShot
	Puff = "rbxassetid://71806534206188",
	Star4 = "rbxassetid://72785377716976",
	Star6 = "rbxassetid://105265033265662",
	Glow = "rbxassetid://133625694739008",
	Streak = "rbxassetid://109649184353418",
	Arc = "rbxassetid://112355157166045", -- 2x2
	Shaft = "rbxassetid://74053531711120",
	Slash = "rbxassetid://88973056407413",
	RingBroken = "rbxassetid://138198378891696",
}
local UPRIGHT = Enum.ParticleOrientation.FacingCameraWorldUp
local FLAT = Enum.ParticleOrientation.VelocityPerpendicular

-- the look of each rare shot: Color = the body, Core = the white-hot middle, Dark = the ink accent
local LOOKS = {
	Mythic = { Rank = 1, Color = Color3.fromRGB(255, 55, 120), Core = Color3.fromRGB(255, 215, 235), Dark = Color3.fromRGB(110, 10, 60) },
	Secret = { Rank = 2, Color = Color3.fromRGB(255, 185, 30), Core = Color3.fromRGB(255, 250, 210), Dark = Color3.fromRGB(80, 30, 120) },
	Divine = { Rank = 3, Color = Color3.fromRGB(255, 200, 60), Core = Color3.fromRGB(255, 250, 225), Dark = Color3.fromRGB(110, 175, 255) },
}

return function(ctx)
	local Kit, Config, State = ctx.Kit, ctx.Config, ctx.State
	local new = Kit.new
	local player = ctx.Player
	local dir = Config.LAUNCH_DIRECTION.Unit
	local side = dir:Cross(Vector3.yAxis).Unit

	local function lowGraphics()
		local s = State.Data and State.Data.Settings
		return s and s.LowGraphics == true
	end
	local function rad(d)
		return math.rad(d)
	end
	local function ease(x)
		x = math.clamp(x, 0, 1)
		return x * x * (3 - 2 * x)
	end
	local function outCubic(x)
		x = math.clamp(x, 0, 1)
		return 1 - (1 - x) ^ 3
	end

	-- every world piece of a shot goes in here
	local fx = new("Folder", { Name = "AnimeFX", Parent = workspace })

	-----------------------------------------------------------------------
	-- Camera layers: the cutscene camera (Camera+1), then shake and
	-- hit-stop on top (Camera+2). Writes are absolute every frame, so
	-- nothing piles up; if nobody moved the camera since our last offset,
	-- we undo it first.
	-----------------------------------------------------------------------
	local cine = nil -- { Get = function(t) -> CFrame, fov; T0 = clock }
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
	local frozen = {} -- emitters that hold still during a hit-stop
	local function hitStop(length, holdCamera)
		freezeUntil = os.clock() + length
		frozenAt = holdCamera and workspace.CurrentCamera.CFrame or nil
		for _, pe in ipairs(frozen) do
			if pe.Parent then
				pe.TimeScale = 0.05 -- never 0 (note 16 §4)
			end
		end
		task.delay(length, function()
			for i = #frozen, 1, -1 do
				if frozen[i].Parent then
					frozen[i].TimeScale = 1
				else
					table.remove(frozen, i)
				end
			end
		end)
	end
	RunService:BindToRenderStep("AnimeFXCine", Enum.RenderPriority.Camera.Value + 1, function()
		if not cine then
			return
		end
		local cam = workspace.CurrentCamera
		local cf, fov = cine.Get(os.clock() - cine.T0)
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = cf
		cam.FieldOfView = fov or 70
	end)
	RunService:BindToRenderStep("AnimeFXShake", Enum.RenderPriority.Camera.Value + 2, function()
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
			local amp = shakeAmp * a * a -- trauma squared
			out = base * CFrame.new((math.random() - 0.5) * amp, (math.random() - 0.5) * amp, 0) * CFrame.Angles(0, 0, (math.random() - 0.5) * amp * 0.03)
		end
		if out ~= base then
			cam.CFrame = out
			lastWritten, lastBase = out, base
		end
	end)

	-----------------------------------------------------------------------
	-- Screen: letterbox bars, the title card, impact frames, focus lines
	-----------------------------------------------------------------------
	local gui = new("ScreenGui", { Name = "AnimeFX", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 45, Parent = player:WaitForChild("PlayerGui") })
	local lineLayer = new("Frame", { Name = "Lines", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = gui })
	local bars = {}
	for i, y in ipairs({ 0, 1 }) do
		bars[i] = new("Frame", {
			Name = "Bar", BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, AnchorPoint = Vector2.new(0, y),
			Position = UDim2.fromScale(0, y), Size = UDim2.fromScale(1, 0), ZIndex = 5, Parent = gui,
		})
	end
	local function setBars(on)
		for _, b in ipairs(bars) do
			TweenService:Create(b, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(1, on and 0.1 or 0) }):Play()
		end
	end
	local card = new("Frame", { Name = "Card", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.2), Size = UDim2.fromOffset(700, 140), Visible = false, ZIndex = 6, Parent = gui })
	local cardScale = new("UIScale", { Parent = card })
	local title = Kit.text({ Text = "", Size = 72, FrameSize = UDim2.new(1, 0, 0, 84), Parent = card })
	local odds = Kit.text({ Text = "", Size = 30, FrameSize = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 86), Parent = card })
	for _, t in ipairs({ title, odds }) do
		t.ZIndex = 7
	end
	local function showCard(name, oddsText, look)
		card.Visible = true
		title.Text, title.TextColor3 = name, look.Color:Lerp(Color3.new(1, 1, 1), 0.15)
		odds.Text, odds.TextColor3 = oddsText, Color3.new(1, 1, 1)
		for _, t in ipairs({ title, odds }) do
			t.TextTransparency = 0
			local st = t:FindFirstChildOfClass("UIStroke")
			if st then
				st.Transparency = 0
				st.Color = look.Dark
			end
		end
		-- the title slams in (1.6 -> 1 in 0.2 s, Back)
		cardScale.Scale = 1.6
		TweenService:Create(cardScale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		Kit.playSound("RareSting")
	end
	local function hideCard()
		for _, t in ipairs({ title, odds }) do
			TweenService:Create(t, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
			local st = t:FindFirstChildOfClass("UIStroke")
			if st then
				TweenService:Create(st, TweenInfo.new(0.25), { Transparency = 1 }):Play()
			end
		end
		task.delay(0.3, function()
			if title.TextTransparency > 0.9 then
				card.Visible = false
			end
		end)
	end

	local grade = new("ColorCorrectionEffect", { Name = "AnimeImpact", Enabled = false, Parent = Lighting })
	local sky = new("ColorCorrectionEffect", { Name = "AnimeSky", Enabled = false, Parent = Lighting })
	local dim = new("ColorCorrectionEffect", { Name = "AnimeDim", Enabled = false, Parent = Lighting })
	local lastFlash = -10
	-- the world darkens before a hit and comes back after (vault note 22 §2: contrast makes the hit)
	local function worldDim(brightness, seconds, saturation)
		dim.Enabled = true
		local tw = TweenService:Create(dim, TweenInfo.new(seconds, Enum.EasingStyle.Quad), { Brightness = brightness, Saturation = saturation or 0 })
		if brightness == 0 then
			tw.Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed then
					dim.Enabled = false
				end
			end)
		end
		tw:Play()
	end
	-- ink strokes drawn over the screen during an impact frame
	local inkLayer = new("Frame", { Name = "Ink", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = gui })
	local inks = {}
	for i = 1, 9 do
		inks[i] = new("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, ZIndex = 3, Parent = inkLayer })
	end
	local function inkOff()
		for _, img in ipairs(inks) do
			img.Visible = false
		end
	end

	local LINES = 40
	local lines = {}
	for i = 1, LINES do
		lines[i] = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Visible = false, Parent = lineLayer })
	end
	local lineConn = nil
	local function stopLines()
		if lineConn then
			lineConn:Disconnect()
			lineConn = nil
		end
		for _, l in ipairs(lines) do
			l.Visible = false
		end
	end
	-- anime focus lines rushing in towards a point (charge) or out from it (release)
	local function focusLines(screenPos, look, seconds, inward)
		stopLines()
		local view = workspace.CurrentCamera.ViewportSize
		local reach = view.Magnitude * 0.6
		local count = 28 + look.Rank * 4
		local state = {}
		for i = 1, count do
			local a = (i / count + math.random() * 0.5 / count) * math.pi * 2
			state[i] = { A = a, R = reach * (0.3 + math.random() * 0.25), Len = reach * (0.25 + math.random() * 0.35), W = 2 + math.random() * 4, Ph = math.random() }
			lines[i].Rotation = math.deg(a)
			lines[i].BackgroundColor3 = i % 3 == 0 and look.Color or (i % 7 == 0 and look.Dark or Color3.new(1, 1, 1))
			lines[i].Visible = true
		end
		local t0 = os.clock()
		lineConn = RunService.RenderStepped:Connect(function()
			local k = (os.clock() - t0) / seconds
			if k >= 1 then
				stopLines()
				return
			end
			-- peak early, then fade (note 16 §1: the hit lands in the first 25%)
			local alpha = k < 0.15 and k / 0.15 or 1 - (k - 0.15) / 0.85
			for i = 1, count do
				local s, l = state[i], lines[i]
				local drift = inward and (1 - ((k * 3 + s.Ph) % 1)) or k
				local r = s.R + reach * 0.45 * drift
				local c = Vector2.new(math.cos(s.A), math.sin(s.A))
				local p = screenPos + c * (r + s.Len / 2)
				l.Position = UDim2.fromOffset(p.X, p.Y)
				l.Size = UDim2.fromOffset(s.Len, s.W * (inward and 1 or (1 - k)))
				l.BackgroundTransparency = 1 - 0.85 * alpha
			end
		end)
	end
	-- speed lines while the ball cruises: with the chase camera behind the ball they rush outward from it,
	-- like flying down a tunnel (Alex, Oct 31: the flight is seen from behind now)
	local function flightStreaks(ball, duration, look)
		stopLines()
		local cam = workspace.CurrentCamera
		local view = cam.ViewportSize
		local reach = view.Magnitude * 0.6
		local count = 16 + look.Rank * 6
		local state = {}
		local function respawn(s, anywhere)
			s.A = math.random() * math.pi * 2
			s.R = reach * (anywhere and (0.2 + math.random() * 0.8) or (0.18 + math.random() * 0.1))
			s.Len, s.W, s.Speed = 60 + math.random() * 200, 1 + math.random() * 2.5, 1400 + math.random() * 1400
		end
		for i = 1, count do
			state[i] = {}
			respawn(state[i], true)
			lines[i].BackgroundColor3 = i % 4 == 0 and look.Color or Color3.new(1, 1, 1)
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
			local strength = math.max(0, 1 - t / 1.5) * 0.6 + 0.3
			if u > 0.7 then
				strength *= math.max(0, (0.9 - u) / 0.2)
			end
			local sp, onScreen = cam:WorldToViewportPoint(ball.Position)
			local center = onScreen and Vector2.new(sp.X, sp.Y) or view / 2
			for i = 1, count do
				local s, l = state[i], lines[i]
				s.R += s.Speed * dt * (s.R / reach + 0.3) -- faster towards the edges, like perspective
				if s.R > reach then
					respawn(s, false)
				end
				local c = Vector2.new(math.cos(s.A), math.sin(s.A))
				local p = center + c * (s.R + s.Len / 2)
				l.Rotation = math.deg(s.A)
				l.Position = UDim2.fromOffset(p.X, p.Y)
				l.Size = UDim2.fromOffset(s.Len * (0.5 + s.R / reach), s.W)
				l.BackgroundTransparency = 1 - 0.55 * strength * math.min(s.R / (reach * 0.35), 1)
			end
		end)
	end

	-----------------------------------------------------------------------
	-- World pieces
	-----------------------------------------------------------------------
	local function emitter(parent, props)
		local pe = new("ParticleEmitter", props)
		pe.Parent = parent
		table.insert(frozen, pe)
		return pe
	end
	local function part(props)
		local p = new("Part", props)
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		if not props.Parent then
			p.Parent = fx
		end
		return p
	end
	local function fadeSeq(a, b)
		return NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.1, a), NumberSequenceKeypoint.new(0.6, b or a), NumberSequenceKeypoint.new(1, 1) })
	end
	-- a one-shot burst at a point: emitters built, Emit()ed and cleaned up (bursts use Emit, never Rate)
	local function burstAt(cf, list)
		local att = new("Attachment", { Parent = workspace.Terrain })
		att.WorldCFrame = cf
		local longest = 0
		for _, spec in ipairs(list) do
			local count = spec.Count
			spec.Count = nil
			local pe = emitter(att, spec)
			pe.Enabled = false
			pe:Emit(count)
			longest = math.max(longest, pe.Lifetime.Max)
		end
		Debris:AddItem(att, longest + 0.5)
		return att
	end
	-- a flat ring that blows out and fades (Expo Out grow, peak early)
	local function ringAt(cf, color, from, to, life, thick)
		local ring = part({ Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = color, Transparency = 0.1, Size = Vector3.new(thick or 0.3, from, from), CFrame = cf })
		TweenService:Create(ring, TweenInfo.new(life, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), { Size = Vector3.new(0.05, to, to) }):Play()
		TweenService:Create(ring, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
		Debris:AddItem(ring, life + 0.05)
		return ring
	end
	local FLOOR = CFrame.Angles(0, 0, rad(90))
	-- the anime shockwave: a cel ring flipbook on the floor plus a neon ring and cel puffs rolling out
	local function shockwave(pos, look, radius)
		ringAt(CFrame.new(pos + Vector3.new(0, 0.3, 0)) * FLOOR, look.Core, radius * 0.2, radius * 2, 0.45, 0.4)
		burstAt(CFrame.new(pos + Vector3.new(0, 0.4, 0)), {
			{ Texture = TEX.Shockwave, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
				Orientation = FLAT, Speed = NumberRange.new(0.01), EmissionDirection = Enum.NormalId.Top, Color = ColorSequence.new(look.Color),
				LightEmission = 0.6, LightInfluence = 0, Size = NumberSequence.new(radius * 2.2), Lifetime = NumberRange.new(0.5), Count = 1 },
			{ Texture = TEX.CelPuff, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
				Color = ColorSequence.new(Color3.fromRGB(245, 240, 230)), LightEmission = 0, LightInfluence = 0.6,
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, radius * 0.25), NumberSequenceKeypoint.new(1, radius * 0.55) }),
				Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(radius * 1.2, radius * 2), SpreadAngle = Vector2.new(90, 4),
				EmissionDirection = Enum.NormalId.Front, Drag = 4, Rotation = NumberRange.new(0, 360), Count = 14 },
		})
	end
	-- energy crackle: a jagged bolt of neon segments, gone in a blink
	local function bolt(from, to, color, width, pieces)
		pieces = pieces or 4
		local prev = from
		local folder = new("Folder", { Name = "Bolt", Parent = fx })
		for i = 1, pieces do
			local p = i == pieces and to or from:Lerp(to, i / pieces) + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * (from - to).Magnitude * 0.3
			part({ Material = Enum.Material.Neon, Color = color, Size = Vector3.new(width, width, (p - prev).Magnitude), CFrame = CFrame.lookAt((prev + p) / 2, p), Parent = folder })
			prev = p
		end
		Debris:AddItem(folder, 0.08)
	end
	-- one flame tongue: a neon teardrop that shoots along `up`, stretches thin and fades late
	local function tongue(base, up, height, width, color, alpha, life)
		local s = math.abs(up.Unit:Dot(Vector3.yAxis)) > 0.95 and Vector3.xAxis or up.Unit:Cross(Vector3.yAxis).Unit
		local cf = CFrame.fromMatrix(base, s, up.Unit)
		local p = part({ Material = Enum.Material.Neon, Color = color, Transparency = alpha, Size = Vector3.new(width, height * 0.25, width), CFrame = cf })
		new("SpecialMesh", { MeshType = Enum.MeshType.Sphere, Parent = p })
		TweenService:Create(p, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(width * 0.3, height, width * 0.3), CFrame = cf + cf.YVector * height * 0.55 }):Play()
		TweenService:Create(p, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
		Debris:AddItem(p, life + 0.05)
	end
	-- energy shot from a to b along a curve (the "pumping" stream)
	local function mote(a, b, color, size, life)
		local p = part({ Material = Enum.Material.Neon, Color = color, Shape = Enum.PartType.Ball, Size = Vector3.one * size, Position = a })
		local mid = (a + b) / 2 + Vector3.new(0, (b - a).Magnitude * 0.25, 0) + side * (math.random() - 0.5) * (b - a).Magnitude * 0.3
		local t0 = os.clock()
		local conn
		conn = RunService.Heartbeat:Connect(function()
			local k = (os.clock() - t0) / life
			if k >= 1 or not p.Parent then
				conn:Disconnect()
				p:Destroy()
				return
			end
			local e = k * k -- speeds up into the target
			p.Position = (1 - e) ^ 2 * a + 2 * (1 - e) * e * mid + e * e * b
			p.Size = Vector3.one * size * (1 - 0.6 * k)
		end)
	end
	-- rocks burst up in a ring round a point, coloured like the floor, then sink away
	local floorRay = RaycastParams.new()
	floorRay.FilterType = Enum.RaycastFilterType.Exclude
	local function crater(pos, count, scale)
		if lowGraphics() then
			return
		end
		floorRay.FilterDescendantsInstances = { fx, player.Character }
		local hit = workspace:Raycast(pos + Vector3.new(0, 3, 0), Vector3.new(0, -12, 0), floorRay)
		if not hit then
			return
		end
		scale = scale or 1
		local folder = new("Folder", { Name = "Crater", Parent = fx })
		for i = 1, count do
			local a = (i / count) * math.pi * 2 + math.random() * 0.3
			local out = Vector3.new(math.cos(a), 0, math.sin(a))
			local size = Vector3.new(1.2, 1, 1.2) * (0.8 + math.random() * 0.7) * scale
			local at = hit.Position + out * (3 + math.random()) * scale
			local up = CFrame.lookAt(at, at + out) * CFrame.Angles(rad(-25 - math.random() * 20), 0, 0)
			local rock = part({ Size = size, Color = hit.Instance.Color:Lerp(Color3.new(0, 0, 0), math.random() * 0.2), Material = Enum.Material.Slate, CFrame = up - Vector3.new(0, size.Y, 0), Parent = folder })
			TweenService:Create(rock, TweenInfo.new(0.12, Enum.EasingStyle.Back), { CFrame = up }):Play()
			task.delay(2.5, function()
				TweenService:Create(rock, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = up - Vector3.new(0, size.Y * 1.5, 0) }):Play()
			end)
		end
		Debris:AddItem(folder, 3.5)
	end

	-----------------------------------------------------------------------
	-- Alex's VFX pack (RareFXPack: the pack's effects as data). fxPlay builds
	-- one at a point (or riding a part), scaled by S and recoloured to the
	-- shot's look, and fires it the way the pack's VFX Forge attributes say:
	-- Emit.Count bursts, Emit.Duration runs the emitter for that long.
	-----------------------------------------------------------------------
	local Pack = require(script.Parent:WaitForChild("RareFXPack"))
	local function seq(flat, s)
		local kp = {}
		for i = 1, #flat, 3 do
			table.insert(kp, NumberSequenceKeypoint.new(flat[i], flat[i + 1] * s, flat[i + 2] * s))
		end
		return NumberSequence.new(kp)
	end
	-- white parts of a pack effect take the shot's core colour, coloured parts its body colour
	local function tint(flat, look)
		local kp = {}
		for i = 1, #flat, 4 do
			local r, g, b = flat[i + 1], flat[i + 2], flat[i + 3]
			local hi, lo = math.max(r, g, b), math.min(r, g, b)
			local c = look and look.Color:Lerp(look.Core, hi > 0 and lo / hi or 0) or Color3.new(r, g, b)
			table.insert(kp, ColorSequenceKeypoint.new(flat[i], c))
		end
		return ColorSequence.new(kp)
	end
	local function packEmitter(spec, s, look, parent)
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxassetid://" .. spec.T
		pe.Rate = spec.Rate or 20
		pe.LightEmission, pe.LightInfluence = spec.LightEmission or 0, spec.LightInfluence or 0
		pe.Brightness = math.min(spec.Brightness or 1, 6) -- the pack runs some at 25: too hot on a bright map
		pe.ZOffset, pe.Drag = spec.ZOffset or 0, spec.Drag or 0
		pe.LockedToPart = spec.LockedToPart == true
		pe.FlipbookStartRandom = spec.FlipbookStartRandom == true
		pe.Size = seq(spec.Size, s)
		pe.Transparency = spec.Tr and seq(spec.Tr, 1) or NumberSequence.new(0)
		if spec.Sq then
			pe.Squash = seq(spec.Sq, 1)
		end
		pe.Color = tint(spec.Col, look)
		local function range(v, k)
			return v and NumberRange.new(v[1] * (k or 1), v[2] * (k or 1))
		end
		pe.Lifetime = range(spec.Life) or pe.Lifetime
		pe.Rotation = range(spec.Rot) or NumberRange.new(0)
		pe.RotSpeed = range(spec.RotS) or NumberRange.new(0)
		pe.FlipbookFramerate = range(spec.FbR) or NumberRange.new(1)
		pe.Speed = range(spec.Spd, s) or NumberRange.new(0)
		pe.SpreadAngle = spec.Spr and Vector2.new(spec.Spr[1], spec.Spr[2]) or Vector2.zero
		pe.Acceleration = spec.Acc and Vector3.new(spec.Acc[1], spec.Acc[2], spec.Acc[3]) * s or Vector3.zero
		pe.EmissionDirection = Enum.NormalId:FromValue(spec.Dir or 0)
		pe.Orientation = Enum.ParticleOrientation:FromValue(spec.Ori or 0)
		pe.FlipbookLayout = Enum.ParticleFlipbookLayout:FromValue(spec.FbL or 0)
		pe.FlipbookMode = Enum.ParticleFlipbookMode:FromValue(spec.FbM or 0)
		if spec.Shp then
			pe.Shape = Enum.ParticleEmitterShape:FromValue(spec.Shp)
		end
		pe.Enabled = false
		pe.Parent = parent
		table.insert(frozen, pe)
		return pe
	end
	-- play a pack effect: at = CFrame (or a part to ride), s = scale, look = recolour (nil keeps the pack's colours),
	-- hold = seconds for the effect's looping emitters (bursts always run their own course)
	local function fxPlay(name, at, s, look, hold)
		local t = Pack[name]
		if not t then
			return
		end
		hold = hold or 0.6
		local host
		if typeof(at) == "Instance" then
			host = new("Part", { Size = Vector3.one * 0.2, Transparency = 1, Anchored = false, CanCollide = false, CanQuery = false, CanTouch = false, Massless = true, CFrame = at.CFrame })
			new("WeldConstraint", { Part0 = at, Part1 = host, Parent = host })
			host.Parent = fx
		elseif type(at) == "function" then
			-- follow: the host is moved to at() every frame (a ball in flight: no roll, facing the way it flies)
			host = part({ Size = Vector3.one * 0.2, Transparency = 1, CFrame = at() })
			local t0 = os.clock()
			local conn
			conn = RunService.Heartbeat:Connect(function()
				local cf = os.clock() - t0 < hold and at()
				if not cf or not host.Parent then
					conn:Disconnect()
					return
				end
				host.CFrame = cf
			end)
		else
			host = part({ Size = Vector3.one * 0.2, Transparency = 1, CFrame = at })
		end
		local atts, longest = {}, 0
		for i, a in ipairs(t.Att) do
			local att = new("Attachment", { Position = Vector3.new(a.At[1], a.At[2], a.At[3]) * s, Parent = host })
			atts[i] = att
			for _, spec in ipairs(a.E) do
				local pe = packEmitter(spec, s, look, att)
				-- the pack built its effects facing -Z: turn their pull with the host
				pe.Acceleration = host.CFrame:VectorToWorldSpace(pe.Acceleration)
				longest = math.max(longest, pe.Lifetime.Max)
				local e = spec.Emit
				if e and hold < 1.5 then
					task.delay(e.Delay or 0, function()
						if (e.Count or 0) > 0 then
							pe:Emit(e.Count)
						end
						if (e.Duration or 0) > 0 then
							pe.Enabled = true
							task.delay(e.Duration, function()
								pe.Enabled = false
							end)
						end
					end)
				elseif spec.Enabled ~= false then
					-- held effects (a ball in flight, a long charge) run every emitter for the whole hold
					pe.Enabled = true
					task.delay(hold, function()
						pe.Enabled = false
					end)
				end
			end
		end
		for _, b in ipairs(t.Beams) do
			local a0, a1 = atts[b.A0], atts[b.A1]
			if a0 and a1 then
				local B = b.B
				new("Beam", {
					Attachment0 = a0, Attachment1 = a1, Texture = "rbxassetid://" .. B.T, LightEmission = B.LightEmission or 1, LightInfluence = B.LightInfluence or 0,
					Brightness = math.min(B.Brightness or 1, 6), TextureLength = B.TextureLength or 1, TextureSpeed = B.TextureSpeed or 1,
					CurveSize0 = (B.CurveSize0 or 0) * s, CurveSize1 = (B.CurveSize1 or 0) * s, Width0 = (B.Width0 or 1) * s, Width1 = (B.Width1 or 1) * s,
					Segments = B.Segments or 10, FaceCamera = B.FaceCamera == true, Transparency = seq(B.Tr, 1), Color = tint(B.Col, look),
					TextureMode = Enum.TextureMode:FromValue(B.TM or 0), Parent = host,
				})
			end
		end
		for _, b in ipairs(t.Trails or {}) do
			local a0, a1 = atts[b.A0], atts[b.A1]
			if a0 and a1 then
				local B = b.B
				local tr = new("Trail", {
					Attachment0 = a0, Attachment1 = a1, LightEmission = B.LightEmission or 0, LightInfluence = B.LightInfluence or 0,
					Brightness = math.min(B.Brightness or 1, 6), Lifetime = (B.Lifetime or 0.3) * math.max(1, s / 3), TextureLength = B.TextureLength or 1,
					MinLength = B.MinLength or 0.1, MaxLength = B.MaxLength or 0, FaceCamera = B.FaceCamera == true,
					Transparency = seq(B.Tr, 1), WidthScale = seq(B.W, 1), Color = tint(B.Col, look), TextureMode = Enum.TextureMode:FromValue(B.TM or 0), Parent = host,
				})
				if B.T then
					tr.Texture = "rbxassetid://" .. B.T
				end
				task.delay(hold, function()
					tr.Enabled = false
				end)
			end
		end
		Debris:AddItem(host, hold + longest + 2)
		return host
	end
	-- the pack's fire aura on every body part (an R15 body or an R6 one), in the shot's colours
	local LIMBS = { "Head", "UpperTorso", "LowerTorso", "Torso", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm",
		"LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }
	local function fireAura(character, look, seconds)
		local list = {}
		for _, n in ipairs(LIMBS) do
			local p = character:FindFirstChild(n)
			if p and p:IsA("BasePart") then
				local att = new("Attachment", { Name = "AnimeFireAura", Parent = p })
				local pe = packEmitter(Pack.FireAura, math.max(p.Size.X, p.Size.Y, p.Size.Z) / 1.6, look, att)
				pe.Enabled = true
				table.insert(list, att)
			end
		end
		task.delay(seconds, function()
			for _, att in ipairs(list) do
				local pe = att:FindFirstChildOfClass("ParticleEmitter")
				if pe then
					pe.Enabled = false
				end
				Debris:AddItem(att, 1.2)
			end
		end)
	end
	local function boreOf(model)
		local bore = model and model:FindFirstChild("Bore", true)
		if bore then
			return bore.Position + dir * 1.5
		end
		return model and model:GetBoundingBox().Position + dir * 3 or nil
	end

	-----------------------------------------------------------------------
	-- Auras (vault note 15 §3): cel flames filling a body box, a force-field
	-- shell, white-hot core flames, spark streaks, a ground glow, arcs,
	-- neon spikes for a sharp silhouette, one light. Works on a character
	-- (welded to the root) or on a cannon (anchored round its bounding box).
	-----------------------------------------------------------------------
	local auras = {}
	local function makeAura(target, look)
		local box, k
		if target:FindFirstChild("HumanoidRootPart") then
			local root = target.HumanoidRootPart
			box = new("Part", { Name = "AnimeAuraBox", Size = Vector3.new(2.6, 3.6, 1.6), Transparency = 1, Anchored = false, CanCollide = false, CanQuery = false, CanTouch = false, Massless = true, CastShadow = false })
			box.CFrame = root.CFrame * CFrame.new(0, -0.9, 0)
			new("WeldConstraint", { Part0 = root, Part1 = box, Parent = box })
			box.Parent = target
			k = 1
		else
			local cf, size = target:GetBoundingBox()
			box = part({ Name = "AnimeAuraBox", Size = size * Vector3.new(0.8, 0.6, 0.8), CFrame = cf * CFrame.new(0, -size.Y * 0.15, 0), Transparency = 1 })
			k = math.max(size.Y / 4.5, 1)
		end
		local rig = { Target = target, Box = box, K = k, Look = look, Power = 0, Debt = 0 }
		local top = new("Attachment", { Position = Vector3.new(0, box.Size.Y * 0.2, 0), Parent = box })
		local feet = new("Attachment", { Position = Vector3.new(0, -box.Size.Y / 2, 0), Parent = box })
		rig.Feet = feet
		local flameCol = ColorSequence.new({
			ColorSequenceKeypoint.new(0, look.Core), ColorSequenceKeypoint.new(0.3, look.Color), ColorSequenceKeypoint.new(1, look.Color:Lerp(look.Dark, 0.5)),
		})
		rig.Flame = emitter(box, {
			Name = "Flames", Texture = TEX.CelFlame, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = Enum.ParticleFlipbookMode.Loop,
			FlipbookFramerate = NumberRange.new(18, 24), FlipbookStartRandom = true, Orientation = UPRIGHT, Squash = NumberSequence.new(0.6, 1),
			Color = flameCol, LightEmission = 0.3, LightInfluence = 0, Brightness = 1.4,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2 * k, 0.4 * k), NumberSequenceKeypoint.new(0.35, 3.4 * k, 0.6 * k), NumberSequenceKeypoint.new(1, 0.8 * k) }),
			Transparency = fadeSeq(0.05, 0.25), Lifetime = NumberRange.new(0.4, 0.6), Speed = NumberRange.new(4 * k, 7 * k),
			SpreadAngle = Vector2.new(10, 10), Acceleration = Vector3.new(0, 18 * k, 0), Drag = 1, EmissionDirection = Enum.NormalId.Top,
			Rotation = NumberRange.new(-8, 8), ZOffset = -0.6, Rate = 0,
		})
		rig.Core = emitter(box, {
			Name = "Core", Texture = TEX.CelFlame, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = Enum.ParticleFlipbookMode.Loop,
			FlipbookFramerate = NumberRange.new(20, 26), FlipbookStartRandom = true, Orientation = UPRIGHT, Squash = NumberSequence.new(0.6),
			Color = ColorSequence.new(Color3.new(1, 1, 1), look.Core), LightEmission = 1, LightInfluence = 0,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2 * k), NumberSequenceKeypoint.new(0.4, 2 * k), NumberSequenceKeypoint.new(1, 0.4 * k) }),
			Transparency = fadeSeq(0.35, 0.55), Lifetime = NumberRange.new(0.3, 0.45), Speed = NumberRange.new(3 * k, 5 * k),
			Acceleration = Vector3.new(0, 12 * k, 0), EmissionDirection = Enum.NormalId.Top, ZOffset = 0.4, Rate = 0,
		})
		rig.Streaks = emitter(feet, {
			Name = "Streaks", Texture = TEX.Streak, Orientation = Enum.ParticleOrientation.VelocityParallel, Color = ColorSequence.new(look.Core),
			LightEmission = 1, LightInfluence = 0, Brightness = 2, Size = NumberSequence.new(0.5 * k, 0), Squash = NumberSequence.new(1.5),
			Lifetime = NumberRange.new(0.2, 0.4), Speed = NumberRange.new(12 * k, 20 * k), SpreadAngle = Vector2.new(25, 25), EmissionDirection = Enum.NormalId.Top, ZOffset = 0.5, Rate = 0,
		})
		rig.Disc = emitter(feet, {
			Name = "Disc", Texture = TEX.Glow, Orientation = FLAT, EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(0.01), LockedToPart = true,
			Color = ColorSequence.new(look.Color), LightEmission = 1, LightInfluence = 0, Size = NumberSequence.new(5 * k, 6.5 * k),
			Transparency = fadeSeq(0.5, 0.6), Lifetime = NumberRange.new(0.6), Rate = 0,
		})
		rig.Arcs = emitter(box, {
			Name = "Arcs", Texture = TEX.Arc, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2, FlipbookMode = Enum.ParticleFlipbookMode.Loop,
			FlipbookFramerate = NumberRange.new(0), FlipbookStartRandom = true, Color = ColorSequence.new(Color3.new(1, 1, 1), look.Core),
			LightEmission = 1, LightInfluence = 0, Brightness = 2.5, Speed = NumberRange.new(0), Size = NumberSequence.new(2.8 * k),
			Lifetime = NumberRange.new(0.12, 0.22), Rotation = NumberRange.new(0, 360), ZOffset = 0.6, Rate = 0,
		})
		-- the shell: a force-field egg that shimmers on its own (note 16 §3)
		rig.Shell = part({
			Name = "AnimeShell", Shape = Enum.PartType.Ball, Material = Enum.Material.ForceField, Color = look.Color, Transparency = 1,
			Size = Vector3.one * math.max(box.Size.X, box.Size.Z) * 2.1, CFrame = box.CFrame * CFrame.new(0, box.Size.Y * 0.2, 0),
		})
		rig.ShellMesh = new("SpecialMesh", { MeshType = Enum.MeshType.Sphere, Scale = Vector3.new(1, 1.5, 1), Parent = rig.Shell })
		rig.Light = new("PointLight", { Color = look.Color, Brightness = 0, Range = 14 * math.min(k, 3), Shadows = false, Parent = top })
		auras[rig] = true
		return rig
	end

	-- how hard an aura burns, 0..1 (rates written only on change)
	local function setPower(rig, power)
		rig.Power = power
		local low = lowGraphics() and 0.4 or 1
		local function rate(pe, value)
			local r = power > 0 and value * low or 0
			if pe.Rate ~= r then
				pe.Rate = r
			end
		end
		rate(rig.Flame, 30 + 90 * power)
		rate(rig.Core, 12 + 36 * power)
		rate(rig.Streaks, power > 0.3 and 8 + 16 * power or 0)
		rate(rig.Disc, power > 0.2 and 4 or 0)
		rate(rig.Arcs, power > 0.6 and 4 + 6 * power or 0)
		rig.Light.Brightness = power > 0 and 1 + 2 * power or 0
	end
	local function pulse(rig, big)
		rig.Flame:Emit(big and 30 or 10)
		rig.Core:Emit(big and 10 or 3)
		rig.Streaks:Emit(big and 24 or 6)
		if big then
			rig.Arcs:Emit(4)
		end
	end
	local function dropAura(rig, after)
		task.delay(after or 0, function()
			if not auras[rig] then
				return
			end
			setPower(rig, 0)
			auras[rig] = nil
			TweenService:Create(rig.Shell, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			Debris:AddItem(rig.Shell, 0.5)
			Debris:AddItem(rig.Box, 1)
		end)
	end
	-- the shell breathes and follows; neon spikes keep the silhouette sharp
	RunService.Heartbeat:Connect(function(dt)
		if os.clock() < freezeUntil then
			return
		end
		local t = os.clock()
		for rig in pairs(auras) do
			if not rig.Box.Parent then
				auras[rig] = nil
			elseif rig.Power > 0 then
				local b = 0.5 + 0.5 * math.sin(t * 7)
				rig.Shell.CFrame = rig.Box.CFrame * CFrame.new(0, rig.Box.Size.Y * 0.2, 0)
				rig.Shell.Transparency = rig.K > 1 and 0.55 - 0.3 * rig.Power + 0.1 * b or 1
				local s = 1 + 0.06 * b + 0.15 * rig.Power
				rig.ShellMesh.Scale = Vector3.new(s, 1.5 * s, s)
				-- on a body the pack's fire aura carries the silhouette; the big neon spikes are for cannons
				rig.Debt += rig.K > 1 and (3 + 9 * rig.Power) * dt or 0
				while rig.Debt >= 1 do
					rig.Debt -= 1
					local a = math.random() * math.pi * 2
					local out = Vector3.new(math.cos(a), 0, math.sin(a))
					local base = rig.Box.Position + out * rig.Box.Size.X * 0.55 + Vector3.new(0, -rig.Box.Size.Y * 0.45 + math.random() * rig.Box.Size.Y * 0.4, 0)
					local core = math.random() < 0.3
					tongue(base, Vector3.yAxis:Lerp(out, 0.12), (core and 2.6 or 3.8) * rig.K * (0.8 + 0.5 * rig.Power), (core and 0.7 or 1.1) * rig.K, core and rig.Look.Core or rig.Look.Color, core and 0.25 or 0.1, 0.45)
				end
			elseif rig.Shell.Transparency < 1 then
				rig.Shell.Transparency = 1
			end
		end
	end)
	-- ramp an aura's power over time
	local function ramp(rig, from, to, seconds)
		local t0 = os.clock()
		local conn
		conn = RunService.Heartbeat:Connect(function()
			local k = (os.clock() - t0) / seconds
			if not auras[rig] then
				conn:Disconnect()
				return
			end
			setPower(rig, from + (to - from) * ease(k))
			if k >= 1 then
				conn:Disconnect()
			end
		end)
	end

	-----------------------------------------------------------------------
	-- The power-up pose: crouch, fists out, trembling; a roar with the head
	-- thrown back; looking up to the sky. Layered on top of the playing
	-- animation through joint Transform after the Animator (works for both
	-- Motor6D and the 2026 AnimationConstraint rigs, note 17 §4).
	-----------------------------------------------------------------------
	local POSES = {
		Stance = {
			Root = CFrame.new(0, -0.55, 0), Waist = CFrame.Angles(rad(-14), 0, 0), Neck = CFrame.Angles(rad(-6), 0, 0),
			LeftShoulder = CFrame.Angles(rad(12), 0, rad(-26)), RightShoulder = CFrame.Angles(rad(12), 0, rad(26)),
			LeftElbow = CFrame.Angles(rad(55), 0, 0), RightElbow = CFrame.Angles(rad(55), 0, 0),
			LeftHip = CFrame.Angles(rad(40), 0, rad(-12)), RightHip = CFrame.Angles(rad(40), 0, rad(12)),
			LeftKnee = CFrame.Angles(rad(-60), 0, 0), RightKnee = CFrame.Angles(rad(-60), 0, 0),
			LeftAnkle = CFrame.Angles(rad(20), 0, 0), RightAnkle = CFrame.Angles(rad(20), 0, 0),
		},
		Roar = {
			Root = CFrame.new(0, -0.2, 0), Waist = CFrame.Angles(rad(24), 0, 0), Neck = CFrame.Angles(rad(26), 0, 0),
			LeftShoulder = CFrame.Angles(rad(20), 0, rad(-60)), RightShoulder = CFrame.Angles(rad(20), 0, rad(60)),
			LeftElbow = CFrame.Angles(rad(-35), 0, 0), RightElbow = CFrame.Angles(rad(-35), 0, 0),
		},
		Sky = {
			Waist = CFrame.Angles(rad(16), 0, 0), Neck = CFrame.Angles(rad(30), 0, 0),
			LeftShoulder = CFrame.Angles(rad(-20), 0, rad(-80)), RightShoulder = CFrame.Angles(rad(-20), 0, rad(80)),
		},
	}
	local pose = { Weight = 0, Target = 0, Character = nil, Joints = {}, Layers = {}, Shake = 0 }
	local function jointsOf(character)
		if pose.Character ~= character then
			pose.Character, pose.Joints = character, {}
			for name in pairs(POSES.Stance) do
				local j = character:FindFirstChild(name, true)
				if j and (j:IsA("Motor6D") or j:IsA("AnimationConstraint")) then
					pose.Joints[name] = j
				end
			end
		end
		return pose.Joints
	end
	-- a layer snaps in over `rise`, holds, then eases out: wind-up, snap, hold, settle (note 15 §6)
	local function poseLayer(name, rise, hold, fall)
		pose.Layers[name] = { T0 = os.clock(), Rise = rise, Hold = hold, Fall = fall }
	end
	local function layerWeight(l, now)
		local s = now - l.T0
		if s < 0 then
			return 0
		elseif s < l.Rise then
			return outCubic(s / l.Rise)
		elseif s < l.Rise + l.Hold then
			return 1
		elseif s < l.Rise + l.Hold + l.Fall then
			return (1 - (s - l.Rise - l.Hold) / l.Fall) ^ 2
		end
		return 0
	end
	RunService.PreSimulation:Connect(function(dt)
		local character = player.Character
		pose.Weight += (pose.Target - pose.Weight) * math.min(dt * 10, 1)
		if pose.Weight < 0.01 or not character then
			return
		end
		local now = os.clock()
		for name, j in pairs(jointsOf(character)) do
			local cf = CFrame.identity:Lerp(POSES.Stance[name], pose.Weight)
			for layerName, l in pairs(pose.Layers) do
				local w = layerWeight(l, now)
				local p = POSES[layerName][name]
				if p and w > 0 then
					cf *= CFrame.identity:Lerp(p, w * pose.Weight)
				end
			end
			if pose.Shake > 0 and (name == "Waist" or name == "Neck" or name == "Root") then
				cf *= CFrame.Angles((math.random() - 0.5) * pose.Shake, 0, (math.random() - 0.5) * pose.Shake)
			end
			j.Transform *= cf
		end
	end)

	-----------------------------------------------------------------------
	-- Cannon charge: tip up slowly, creep back, tremble at the end, then
	-- home exactly (note 16 §4). The release and recoil are Effects'.
	-----------------------------------------------------------------------
	local function chargeCannon(model, seconds, tilt)
		local home = model:GetPivot()
		local _, size = model:GetBoundingBox()
		local rear = home.Position - dir * size.Z * 0.35
		local rel = CFrame.new(rear):ToObjectSpace(home)
		local t0 = os.clock()
		local conn
		conn = RunService.Heartbeat:Connect(function()
			local k = (os.clock() - t0) / seconds
			if not model.Parent then
				conn:Disconnect()
				return
			end
			if k >= 1 then
				conn:Disconnect()
				model:PivotTo(home)
				return
			end
			local e = ease(k)
			local tremble = k > 0.6 and (math.random() - 0.5) * rad(1.5) or 0
			model:PivotTo(CFrame.new(rear - dir * size.Z * 0.02 * e) * CFrame.fromAxisAngle(side, rad(tilt) * e + tremble) * rel)
		end)
	end

	-----------------------------------------------------------------------
	-- The cutscene director
	-----------------------------------------------------------------------
	local token = 0
	local saved = nil -- what the cutscene changed, so it can be put back
	local function release()
		if not saved then
			return
		end
		cine = nil
		local cam = workspace.CurrentCamera
		cam.FieldOfView = saved.Fov
		if not player:GetAttribute("Launching") then
			cam.CameraType = Enum.CameraType.Custom
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				cam.CameraSubject = hum
			end
		end
		local main = player.PlayerGui:FindFirstChild("MainUI")
		if main and saved.Main ~= nil then
			main.Enabled = saved.Main
		end
		setBars(false)
		hideCard()
		pose.Target, pose.Shake = 0, 0
		local sk = gui:FindFirstChild("SkipButton", true)
		if sk then
			sk.Visible = false
		end
		saved = nil
	end
	local skip = Kit.button({ Text = "Skip", Color = "Gray", Size = UDim2.fromOffset(120, 44), Position = UDim2.new(1, -20, 1, -20), Anchor = Vector2.new(1, 1), ZIndex = 8, Parent = gui, OnClick = function()
		if saved then
			token += 1 -- stops the rest of the cutscene's camera beats
			release()
		end
	end })
	local skipFrame = skip.Instance
	skipFrame.Name = "SkipButton"
	if typeof(skipFrame) == "Instance" then
		skipFrame.Visible = false
	end
	local function showSkip(after)
		local my = token
		task.delay(after, function()
			if my == token and saved and typeof(skipFrame) == "Instance" then
				skipFrame.Visible = true
			end
		end)
	end
	local function takeCamera(get)
		local cam = workspace.CurrentCamera
		local main = player.PlayerGui:FindFirstChild("MainUI")
		saved = { Fov = cam.FieldOfView, Main = main and main.Enabled }
		if main then
			main.Enabled = false
		end
		cine = { Get = get, T0 = os.clock() }
		setBars(true)
	end
	-- a camera path through shots: { { At = t, Eye = v3, Look = v3, Fov = n }, ... }, smoothstepped between.
	-- A key can carry Get = function(k) -> eye, look, fov instead, for an orbit or a follow over its segment.
	-- The eye is pulled in front of any piece of the map between it and what it looks at (Alex, Oct 31:
	-- "better angles so we see what's going on")
	local camRay = RaycastParams.new()
	camRay.FilterType = Enum.RaycastFilterType.Include
	local function path(keys)
		local map = workspace:FindFirstChild(Config.Map.Root)
		camRay.FilterDescendantsInstances = map and { map } or {}
		return function(t)
			local a, b = keys[#keys], keys[#keys]
			for i = 1, #keys - 1 do
				if t <= keys[i + 1].At then
					a, b = keys[i], keys[i + 1]
					break
				end
			end
			local eye, look, fov
			if a.Get then
				local k = b.At > a.At and math.clamp((t - a.At) / (b.At - a.At), 0, 1) or 1
				eye, look, fov = a.Get(k)
			else
				local k = b.At > a.At and ease((t - a.At) / (b.At - a.At)) or 1
				local be, bl = b.Eye, b.Look
				if b.Get then
					be, bl = b.Get(0)
				end
				eye, look, fov = a.Eye:Lerp(be or a.Eye, k), a.Look:Lerp(bl or a.Look, k), a.Fov + ((b.Fov or a.Fov) - a.Fov) * k
			end
			local hit = workspace:Raycast(look, eye - look, camRay)
			if hit then
				eye = hit.Position + (look - eye).Unit * 1.5
			end
			return CFrame.lookAt(eye, look), fov
		end
	end
	-- an orbit segment for path(): round `center` from angle a0 to a1 (radians, 0 = the side the camera
	-- usually stands), at `radius` and `height`, looking at `center` + lookUp
	local function orbit(center, radius, height, a0, a1, fov0, fov1, lookUp)
		return function(k)
			local e = ease(k)
			local ang = a0 + (a1 - a0) * e
			local eye = center + (side * math.cos(ang) + dir * math.sin(ang)) * radius + Vector3.new(0, height, 0)
			return eye, center + Vector3.new(0, lookUp or 0, 0), fov0 + (fov1 - fov0) * e
		end
	end
	local function skyTint(color, brightness, seconds)
		sky.Enabled = true
		TweenService:Create(sky, TweenInfo.new(seconds or 0.5, Enum.EasingStyle.Sine), { TintColor = color, Brightness = brightness or 0, Saturation = 0.15 }):Play()
	end
	local function skyBack(seconds)
		local tw = TweenService:Create(sky, TweenInfo.new(seconds or 0.8, Enum.EasingStyle.Sine), { TintColor = Color3.new(1, 1, 1), Brightness = 0, Saturation = 0 })
		tw.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed then
				sky.Enabled = false
			end
		end)
		tw:Play()
	end
	local function at(t, my, f)
		task.delay(t, function()
			if my == token then
				f()
			end
		end)
	end

	-- colour grading that shifts through a cutscene (Alex: "add some change of colour")
	local function tintWorld(tint, saturation, contrast, seconds)
		sky.Enabled = true
		TweenService:Create(sky, TweenInfo.new(seconds or 0.6, Enum.EasingStyle.Sine), { TintColor = tint, Saturation = saturation or 0, Contrast = contrast or 0 }):Play()
	end
	-- a rumble that builds: small shakes growing from `from` to `to` over `seconds` (off on Low Graphics)
	local function rumble(my, from, to, seconds)
		local steps = math.max(math.floor(seconds / 0.2), 1)
		for i = 0, steps - 1 do
			at(i * 0.2, my, function()
				shake(from + (to - from) * i / steps, 0.3)
			end)
		end
	end

	local lingering = nil -- the aura a rare shot leaves on you for a while
	local myCannonLook = nil -- the Divine cannon's saved colours and its wings and halo
	local function restoreCannon()
		if not myCannonLook then
			return
		end
		for p, s in pairs(myCannonLook.Parts) do
			if p.Parent then
				p.Color, p.Material = s[1], s[2]
			end
		end
		for _, x in ipairs(myCannonLook.Extras) do
			x:Destroy()
		end
		myCannonLook = nil
	end

	-- MYTHIC: your aura and the cannon's pump up, energy streams in, a roar, the cannon charges
	local function mythic(owner, seconds, mine, my)
		local look = LOOKS.Mythic
		local char = owner.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		local cannon = mine and workspace:FindFirstChild("MyCannon")
		local you = makeAura(char, look)
		ramp(you, 0.15, 1, seconds * 0.55)
		fireAura(char, look, seconds + 0.5)
		-- wind spirals up round you and energy gathers at your chest (pack tornado and charge-up)
		fxPlay("Tornado", CFrame.new(root.Position - Vector3.new(0, 2.6, 0)), 0.45, look, seconds * 0.55)
		at(0.2, my, function()
			fxPlay("Charge", root, 1.2, look, seconds * 0.3)
		end)
		local gun = cannon and makeAura(cannon, look)
		if gun then
			at(0.1, my, function()
				ramp(gun, 0.1, 1, seconds * 0.75)
			end)
		end
		local feet = root.Position - Vector3.new(0, 3, 0)
		local target = cannon and cannon:GetBoundingBox().Position or root.Position + dir * 10
		if mine then
			local f, r, p = root.CFrame.LookVector, root.CFrame.RightVector, root.Position
			local mid = (p + target) / 2
			local span = (target - p).Magnitude
			takeCamera(path({
				-- a low hero shot in front of you, slowly pushing in while the aura builds
				{ At = 0, Eye = p + f * 11 + r * 4 - Vector3.new(0, 1, 0), Look = p + Vector3.new(0, 1, 0), Fov = 60 },
				{ At = seconds * 0.36, Eye = p + f * 8 + r * 2.5 - Vector3.new(0, 1.2, 0), Look = p + Vector3.new(0, 1.3, 0), Fov = 54 },
				-- the roar: a quick pull back so the whole burst reads
				{ At = seconds * 0.42, Eye = p + f * 12 + r * 5 + Vector3.new(0, 1, 0), Look = p + Vector3.new(0, 1, 0), Fov = 66 },
				-- a raised two-shot: you, the stream of energy and the cannon all in frame
				{ At = seconds * 0.55, Eye = mid + side * (span * 0.9 + 16) - dir * 6 + Vector3.new(0, 9, 0), Look = mid + Vector3.new(0, 1.5, 0), Fov = 64 },
				{ At = seconds * 0.78, Eye = mid + side * (span * 0.8 + 14) + dir * 2 + Vector3.new(0, 7, 0), Look = mid + Vector3.new(0, 1.5, 0), Fov = 60 },
				-- over the charging cannon, looking down the river where the ball will fly
				{ At = seconds, Eye = target - dir * 13 + side * 5 + Vector3.new(0, 6, 0), Look = target + dir * 30 + Vector3.new(0, 2, 0), Fov = 70 },
			}))
			showCard("MYTHIC SHOT!", "1 in 100", look)
			tintWorld(Color3.fromRGB(255, 205, 235), 0.25, 0.15, 0.8) -- the world tints magenta
			rumble(my, 0.05, 0.35, seconds)
			pose.Target, pose.Shake = 1, rad(1)
			focusLines(workspace.CurrentCamera.ViewportSize / 2, look, seconds * 0.45, true)
		end
		-- energy pumps from you into the cannon
		for i = 0, 14 do
			at(0.35 + i * 0.07, my, function()
				local a = root.Position + Vector3.new((math.random() - 0.5) * 2, math.random() * 2, (math.random() - 0.5) * 2)
				mote(a, target + Vector3.new(0, 1, 0), i % 3 == 0 and look.Core or look.Color, 0.5, 0.45)
			end)
		end
		at(seconds * 0.38, my, function()
			if mine then
				poseLayer("Roar", 0.1, 0.35, 0.35)
				Kit.playSound("RarePoof")
				pose.Shake = rad(3)
			end
			pulse(you, true)
			shockwave(feet, look, 6)
			crater(feet, 10)
			fxPlay("Crack", CFrame.new(feet + Vector3.new(0, 0.3, 0)), 1.5, nil, 0.4)
			fxPlay("Wind", CFrame.new(feet + Vector3.new(0, 1, 0)), 1.5, look, 0.3)
			shake(0.6, 0.35)
			if mine then
				tintWorld(Color3.fromRGB(255, 170, 215), 0.45, 0.3, 0.15) -- the colour kicks up on the roar
			end
		end)
		if cannon then
			at(seconds * 0.6, my, function()
				if mine then
					worldDim(-0.15, 0.3) -- the world dims to 70% while it charges
				end
				chargeCannon(cannon, seconds * 0.4 - 0.05, 7)
				fxPlay("Charge", CFrame.new(boreOf(cannon)), 2, look, seconds * 0.4)
				Kit.playSound("RareCharge")
				if gun then
					pulse(gun, true)
				end
			end)
		end
		dropAura(you, seconds + 40) -- a safety net: the flight settles it to a glow first
		if gun then
			dropAura(gun, seconds + 0.3)
		end
		return you
	end

	-- SECRET: the sky turns gold, the camera climbs to the Grand Cannon, lightning and god rays charge it
	local function grandCannon()
		return workspace:FindFirstChild("GrandCannon")
	end
	local function secret(owner, seconds, mine, my)
		local look = LOOKS.Secret
		local char = owner.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local grand = grandCannon()
		if not (root and grand) then
			return
		end
		local gcf, gsize = grand:GetBoundingBox()
		local gpos = gcf.Position
		local bore = grand:FindFirstChild("Bore", true)
		local you = makeAura(char, look)
		ramp(you, 0.3, 1, 0.8)
		fireAura(char, look, seconds + 0.5)
		local gun = makeAura(grand, look)
		if mine then
			tintWorld(Color3.fromRGB(255, 225, 160), 0.3, 0.2, 0.6) -- the world goes gold
			local p, f = root.Position, root.CFrame.LookVector
			local bp = bore and bore.Position or gpos
			takeCamera(path({
				-- you power up gold, then the camera follows your energy up to the crag
				{ At = 0, Eye = p + f * 11 - Vector3.new(0, 0.8, 0), Look = p + Vector3.new(0, 1.2, 0), Fov = 60 },
				{ At = 0.8, Eye = p + f * 15 + Vector3.new(0, 7, 0), Look = p:Lerp(gpos, 0.35) + Vector3.new(0, 6, 0), Fov = 66 },
				{ At = 1.5, Eye = gpos + side * 95 - dir * 30 + Vector3.new(0, 10, 0), Look = gpos, Fov = 70 },
				-- a slow orbit round the Grand Cannon while the lightning hits it
				{ At = 1.6, Get = orbit(gpos, 92, 16, -0.32, 0.55, 68, 58, 6) },
				-- low under the barrel as it tips up, then over its shoulder down the river
				{ At = seconds * 0.8, Eye = gpos + side * 30 + dir * 4 + Vector3.new(0, -10, 0), Look = bp + dir * 25 + Vector3.new(0, 12, 0), Fov = 72 },
				{ At = seconds, Eye = bp - dir * 22 + side * 12 + Vector3.new(0, 10, 0), Look = bp + dir * 70, Fov = 76 },
			}))
			showCard("SECRET SHOT!", "1 in 1,000", look)
			showSkip(1)
			rumble(my, 0.05, 0.25, 1.4)
			pose.Target, pose.Shake = 1, rad(1.5)
			at(0.35, my, function()
				poseLayer("Roar", 0.1, 0.5, 0.4)
				Kit.playSound("RarePoof")
				pose.Shake = rad(3)
			end)
		end
		at(0.4, my, function()
			pulse(you, true)
			shockwave(root.Position - Vector3.new(0, 3, 0), look, 7)
			shake(0.4, 0.3)
			-- a stream of gold leaps from you up to the crag
			for i = 0, 18 do
				at(i * 0.04, my, function()
					mote(root.Position + Vector3.new(0, 1, 0), gpos + Vector3.new(0, 4, 0), i % 3 == 0 and look.Core or look.Color, 0.9, 0.55)
				end)
			end
		end)
		at(1.2, my, function()
			ramp(gun, 0.3, 1, seconds - 1.4)
			-- god rays: beams from the sky onto the cannon
			for i = 1, 4 do
				local a0 = new("Attachment", { Parent = workspace.Terrain })
				a0.WorldPosition = gpos + Vector3.new((i - 2.5) * 22, 160, (i % 2 == 0 and 1 or -1) * 30)
				local a1 = new("Attachment", { Parent = workspace.Terrain })
				a1.WorldPosition = gpos + Vector3.new((i - 2.5) * 4, 0, 0)
				local beam = new("Beam", {
					Attachment0 = a0, Attachment1 = a1, Texture = TEX.Shaft, TextureMode = Enum.TextureMode.Stretch, TextureSpeed = 0.4,
					FaceCamera = true, LightEmission = 0.7, LightInfluence = 0, Width0 = 0, Width1 = 0, Segments = 1,
					Color = ColorSequence.new(look.Core, look.Color),
					Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.45), NumberSequenceKeypoint.new(1, 0.6) }),
					Parent = a0,
				})
				local w = new("NumberValue", { Value = 0, Parent = beam })
				w.Changed:Connect(function(v)
					beam.Width0, beam.Width1 = v * 10, v * 18
				end)
				TweenService:Create(w, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Value = 1 }):Play()
				task.delay(seconds - 1.7, function()
					if w.Parent then
						TweenService:Create(w, TweenInfo.new(0.5), { Value = 0 }):Play()
					end
				end)
				Debris:AddItem(a0, seconds)
				Debris:AddItem(a1, seconds)
			end
		end)
		-- lightning strikes the cannon from the sky
		for i = 0, 9 do
			at(1.4 + i * 0.18, my, function()
				local top = gpos + Vector3.new((math.random() - 0.5) * 60, 120, (math.random() - 0.5) * 60)
				local hit = gpos + Vector3.new((math.random() - 0.5) * gsize.X * 0.6, gsize.Y * 0.2, (math.random() - 0.5) * gsize.Z * 0.6)
				bolt(top, hit, i % 2 == 0 and look.Core or look.Color, 1.1, 7)
				if i % 3 == 0 then
					shockwave(hit, look, 8)
					fxPlay(i % 2 == 0 and "Lightning" or "Lightning2", CFrame.new(hit), 5, look, 0.3)
				end
			end)
		end
		at(1.5, my, function()
			-- a gold storm winds up round the Grand Cannon
			fxPlay("Tornado", CFrame.new(gpos - Vector3.new(0, gsize.Y * 0.4, 0)), 4, look, seconds - 1.6)
			if mine then
				rumble(my, 0.15, 0.6, seconds - 1.6)
				tintWorld(Color3.fromRGB(255, 205, 120), 0.45, 0.35, seconds - 1.6)
			end
		end)
		at(seconds * 0.62, my, function()
			chargeCannon(grand, seconds * 0.38 - 0.05, 5)
			fxPlay("Charge", CFrame.new(boreOf(grand)), 8, look, seconds * 0.38)
			if mine then
				Kit.playSound("RareCharge")
			end
			pulse(gun, true)
			shake(0.35, seconds * 0.38)
		end)
		dropAura(you, seconds + 40)
		dropAura(gun, seconds + 0.5)
		return you
	end

	-- the angel cannon: white and gold, glowing trim, wings that unfold, a turning halo
	local function angelic(cannon, look, seconds)
		restoreCannon()
		local saveParts, extras = {}, {}
		myCannonLook = { Parts = saveParts, Extras = extras }
		local gold = { Ring = true, MuzzleRing = true, Hub = true, Trunnion = true, Knob = true, Gem = true, BodyTrim = true, Rim = true }
		for _, p in ipairs(cannon:GetDescendants()) do
			if p:IsA("BasePart") and p.Name ~= "Bore" and p.Transparency < 1 then
				saveParts[p] = { p.Color, p.Material }
				TweenService:Create(p, TweenInfo.new(seconds, Enum.EasingStyle.Sine), { Color = gold[p.Name] and look.Color or Color3.fromRGB(250, 250, 255) }):Play()
				if gold[p.Name] then
					task.delay(seconds, function()
						if myCannonLook and myCannonLook.Parts == saveParts then
							p.Material = Enum.Material.Neon
						end
					end)
				end
			end
		end
		local cf, size = cannon:GetBoundingBox()
		local s = size.Y / 4
		for _, x in ipairs({ -1, 1 }) do
			local hinge = cf.Position + side * x * size.X * 0.45 + Vector3.new(0, size.Y * 0.15, 0) - dir * size.Z * 0.1
			local wing = new("Model", { Name = "Wing", Parent = fx })
			for i = 1, 7 do
				local len = (6 - i * 0.6) * s
				-- two layers of blocky feathers: white on top, a pale gold row underneath, a glowing gold leading edge
				for layer = 0, 1 do
					part({
						Name = "Feather", Color = i == 1 and look.Color or (layer == 0 and Color3.fromRGB(252, 252, 255) or Color3.fromRGB(255, 236, 190)),
						Material = i == 1 and Enum.Material.Neon or Enum.Material.SmoothPlastic,
						Size = Vector3.new(0.45 * s, len * (1 - layer * 0.25), 0.8 * s),
						CFrame = CFrame.new(hinge + side * x * (0.6 + i * 0.7) * s + Vector3.new(0, len / 2 - i * 0.3 * s - layer * 0.5 * s, 0) - dir * (i * 0.35 + layer * 0.5) * s) * CFrame.fromAxisAngle(dir, -x * rad(8 + i * 8)),
						Parent = wing,
					})
				end
			end
			local open = wing:GetPivot()
			local offset = CFrame.new(hinge):ToObjectSpace(open)
			local v = new("NumberValue", { Value = 1, Parent = wing })
			v.Changed:Connect(function(k)
				wing:PivotTo(CFrame.new(hinge) * CFrame.fromAxisAngle(dir, x * rad(95) * k) * offset)
			end)
			wing:PivotTo(CFrame.new(hinge) * CFrame.fromAxisAngle(dir, x * rad(95)) * offset)
			local open = TweenService:Create(v, TweenInfo.new(0.7, Enum.EasingStyle.Back), { Value = 0 })
			open.Completed:Connect(function()
				-- then a slow, gentle flap while it waits (slower than once a second: calm, kid-safe)
				local t0 = os.clock()
				local flap
				flap = RunService.Heartbeat:Connect(function()
					if not wing.Parent then
						flap:Disconnect()
						return
					end
					local a = math.sin((os.clock() - t0) * 2.4) * rad(9)
					wing:PivotTo(CFrame.new(hinge) * CFrame.fromAxisAngle(dir, x * a) * offset)
				end)
			end)
			open:Play()
			table.insert(extras, wing)
		end
		local halo = new("Model", { Name = "Halo", Parent = fx })
		local hc = cf.Position + Vector3.new(0, size.Y * 0.75 + 1.5 * s, 0)
		for i = 1, 12 do
			local a = i / 12 * math.pi * 2
			part({ Name = "HaloBlock", Color = look.Color, Material = Enum.Material.Neon, Size = Vector3.new(0.6, 0.4, 1) * s, CFrame = CFrame.new(hc + Vector3.new(math.cos(a), 0, math.sin(a)) * 1.8 * s) * CFrame.Angles(0, -a, 0), Parent = halo })
		end
		local glowPart = part({ Name = "HaloGlow", Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(hc), Parent = halo })
		new("PointLight", { Color = look.Color, Brightness = 3, Range = 18, Shadows = false, Parent = glowPart })
		fxPlay("Shiny", CFrame.new(hc), 2.5, look, 6)
		local spin = RunService.Heartbeat:Connect(function(dt)
			if halo.Parent then
				halo:PivotTo(halo:GetPivot() * CFrame.Angles(0, dt * 1.6, 0))
			end
		end)
		halo.Destroying:Connect(function()
			spin:Disconnect()
		end)
		table.insert(extras, halo)
	end

	-- DIVINE: the heavens open over your cannon, a column of light, feathers, wings and a halo
	local function divine(owner, seconds, mine, my)
		local look = LOOKS.Divine
		local char = owner.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		local cannon = mine and workspace:FindFirstChild("MyCannon")
		local focus = cannon and cannon:GetBoundingBox().Position or root.Position
		local heaven = focus + Vector3.new(0, 140, 0)
		if mine then
			skyTint(Color3.fromRGB(150, 165, 225), -0.12, 0.7) -- the sky goes navy
			local p = root.Position
			takeCamera(path({
				-- a close-up on the cannon waking (its eyes and halo), then up to the sky as the heavens open
				{ At = 0, Eye = focus + side * 13 + dir * 7 + Vector3.new(0, 2.5, 0), Look = focus + dir * 2 + Vector3.new(0, 1.5, 0), Fov = 52 },
				{ At = 0.9, Eye = focus + side * 11 + dir * 6 + Vector3.new(0, 2.5, 0), Look = focus + dir * 2 + Vector3.new(0, 1.5, 0), Fov = 48 },
				-- up to the sky as the heavens open, then wide as the column comes down
				{ At = 1.5, Eye = focus + side * 45 - dir * 18 + Vector3.new(0, 4, 0), Look = focus + Vector3.new(0, 60, 0), Fov = 72 },
				{ At = 2.3, Eye = focus + side * 42 - dir * 8 + Vector3.new(0, 14, 0), Look = focus + Vector3.new(0, 8, 0), Fov = 66 },
				-- the showcase: a slow orbit round the angel cannon so you really see it
				-- (high and wide enough to clear the dock props, so the camera never gets pulled into the wings)
				{ At = 2.6, Get = orbit(focus, 34, 13, 0.1, 3.3, 60, 52, 4) },
				-- behind you, looking up past the cannon to the light
				{ At = seconds - 1.4, Eye = p + (p - focus).Unit * 10 + Vector3.new(0, 4, 0), Look = focus + Vector3.new(0, 7, 0), Fov = 62 },
				-- over the cannon, down the river
				{ At = seconds - 0.6, Eye = focus - dir * 14 + side * 6 + Vector3.new(0, 7, 0), Look = focus + dir * 40 + Vector3.new(0, 2, 0), Fov = 70 },
				{ At = seconds, Eye = focus - dir * 13 + side * 5 + Vector3.new(0, 6.5, 0), Look = focus + dir * 45 + Vector3.new(0, 2, 0), Fov = 74 },
			}))
			showCard("DIVINE SHOT!", "1 in 100,000", look)
			showSkip(1)
			if cannon then
				-- the cannon wakes: two glowing eyes on the barrel and a spiked halo turning behind it (Ref 3)
				local bore = boreOf(cannon)
				for _, x in ipairs({ -1, 1 }) do
					burstAt(CFrame.new(bore - dir * (2.2 - x * 0.8) + side * 1.8 + Vector3.new(0, 0.8, 0)), { -- on the camera's side of the barrel
						{ Texture = TEX.Star4, Color = ColorSequence.new(look.Core, look.Dark), LightEmission = 1, LightInfluence = 0, Brightness = 2,
							Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.15, 3.5), NumberSequenceKeypoint.new(1, 2) }),
							Lifetime = NumberRange.new(1.4), Speed = NumberRange.new(0), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-60, 60), ZOffset = 1, Count = 1 },
					})
				end
				burstAt(CFrame.new(focus - side * 5 + Vector3.new(0, 2, 0)), { -- behind the cannon from the close-up
					{ Texture = TEX.RingBroken, Color = ColorSequence.new(look.Core, look.Dark), LightEmission = 1, LightInfluence = 0,
						Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(0.3, 22), NumberSequenceKeypoint.new(1, 24) }),
						Transparency = fadeSeq(0.1, 0.3), Lifetime = NumberRange.new(1.6), Speed = NumberRange.new(0), RotSpeed = NumberRange.new(90), ZOffset = -3, Count = 1 },
				})
			end
		end
		at(0.9, my, function()
			-- the heavens open: a bright disc in the sky with a slow star burst
			local disc = part({ Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = look.Core, Transparency = 1, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(heaven) * FLOOR })
			TweenService:Create(disc, TweenInfo.new(0.9, Enum.EasingStyle.Exponential), { Size = Vector3.new(1, 60, 60), Transparency = 0.25 }):Play()
			emitter(new("Attachment", { Parent = disc }), {
				Texture = TEX.Star6, Color = ColorSequence.new(look.Core, look.Color), LightEmission = 1, LightInfluence = 0,
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 50), NumberSequenceKeypoint.new(1, 60) }),
				Transparency = fadeSeq(0.3, 0.5), Lifetime = NumberRange.new(1.2), Rate = 2, Speed = NumberRange.new(0),
				Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-10, 10),
			})
			task.delay(seconds + 0.5, function()
				TweenService:Create(disc, TweenInfo.new(0.8), { Transparency = 1, Size = Vector3.new(1, 90, 90) }):Play()
				Debris:AddItem(disc, 0.9)
			end)
		end)
		at(1.6, my, function()
			-- the column of light grows down from the sky onto the cannon
			local height = heaven.Y - focus.Y
			local col = part({ Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = look.Core, Transparency = 0.5, Size = Vector3.new(1, 9, 9), CFrame = CFrame.new(heaven) * FLOOR })
			local v = new("NumberValue", { Value = 0, Parent = col })
			v.Changed:Connect(function(k)
				col.Size = Vector3.new(math.max(height * k, 1), 9, 9)
				col.CFrame = CFrame.new(heaven - Vector3.new(0, height * k / 2, 0)) * FLOOR
			end)
			TweenService:Create(v, TweenInfo.new(0.8, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { Value = 1 }):Play()
			local outer = part({ Shape = Enum.PartType.Cylinder, Material = Enum.Material.ForceField, Color = look.Color, Transparency = 1, Size = Vector3.new(height, 18, 18), CFrame = CFrame.new(heaven - Vector3.new(0, height / 2, 0)) * FLOOR })
			at(0.8, my, function()
				outer.Transparency = 0.45
				TweenService:Create(col, TweenInfo.new(0.6), { Transparency = 0.82 }):Play() -- the cannon shows through
				shockwave(focus - Vector3.new(0, 4, 0), look, 12)
				shake(0.5, 0.35)
				if cannon then
					angelic(cannon, look, 1.2)
				end
				if mine then
					tintWorld(Color3.fromRGB(255, 240, 215), 0.2, 0.2, 0.8) -- navy turns to warm white-gold
					rumble(my, 0.25, 0.05, 0.8)
				end
				fxPlay("HolyAura", CFrame.new(focus - Vector3.new(0, 4, 0)), 3, look, seconds)
				fxPlay("Stars", CFrame.new(focus + Vector3.new(0, 6, 0)), 3, look, seconds)
			end)
			-- feathers drift down through the light
			local cloud = part({ Size = Vector3.new(40, 1, 40), Transparency = 1, CFrame = CFrame.new(focus + Vector3.new(0, 45, 0)) })
			emitter(cloud, {
				Texture = TEX.Puff, Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)), LightEmission = 0, LightInfluence = 0.3,
				Squash = NumberSequence.new(1.2), Size = NumberSequence.new(0.9, 0.7), Transparency = fadeSeq(0.05, 0.2), Lifetime = NumberRange.new(4, 6),
				Speed = NumberRange.new(2, 4), EmissionDirection = Enum.NormalId.Bottom, Acceleration = Vector3.new(0, -1, 0), Drag = 0.5,
				Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-120, 120), Rate = lowGraphics() and 8 or 20,
			})
			emitter(cloud, {
				Texture = TEX.Star4, Color = ColorSequence.new(look.Core, look.Color), LightEmission = 1, LightInfluence = 0,
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 1.6), NumberSequenceKeypoint.new(1, 0) }),
				Lifetime = NumberRange.new(1.5, 2.5), Speed = NumberRange.new(4, 8), EmissionDirection = Enum.NormalId.Bottom, Rate = 14,
				Rotation = NumberRange.new(0, 360),
			})
			task.delay(seconds + 0.6, function()
				TweenService:Create(col, TweenInfo.new(0.6), { Transparency = 1 }):Play()
				TweenService:Create(outer, TweenInfo.new(0.6), { Transparency = 1 }):Play()
				for _, pe in ipairs(cloud:GetChildren()) do
					pe.Enabled = false
				end
				Debris:AddItem(col, 0.7)
				Debris:AddItem(outer, 0.7)
				Debris:AddItem(cloud, 6)
			end)
		end)
		local you = makeAura(char, look)
		at(seconds - 1.5, my, function()
			ramp(you, 0.3, 1, 0.8)
			pulse(you, true)
			fxPlay("Shiny", root, 1.5, look, 1.5)
			if mine then
				pose.Target, pose.Shake = 1, rad(1.5)
				poseLayer("Sky", 0.15, 1.2, 0.5)
				Kit.playSound("RarePoof")
			end
			for i = 0, 12 do
				at(i * 0.05, my, function()
					mote(root.Position + Vector3.new(0, 1.5, 0), focus + Vector3.new(0, 2, 0), i % 2 == 0 and look.Core or look.Dark, 0.6, 0.5)
				end)
			end
		end)
		if cannon then
			local gun = makeAura(cannon, look)
			at(2.4, my, function()
				ramp(gun, 0.2, 1, seconds - 2.6)
			end)
			at(seconds - 1.2, my, function()
				if mine then
					rumble(my, 0.1, 0.5, 1.15)
				end
				fxPlay("Charge", CFrame.new(boreOf(cannon)), 2.5, look, 1.15)
				chargeCannon(cannon, 1.15, 6)
				Kit.playSound("RareCharge")
				pulse(gun, true)
			end)
			dropAura(gun, seconds + 0.3)
		end
		dropAura(you, seconds + 40)
		return you
	end

	local PLAYS = { Mythic = mythic, Secret = secret, Divine = divine }

	-- a Secret ball leaves the big golden cannon (Effects asks this before it fires)
	function ctx.RareMuzzle(rareId)
		if rareId == "Secret" then
			local grand = grandCannon()
			local bore = grand and grand:FindFirstChild("Bore", true)
			if bore then
				return bore.Position + dir * 4
			end
		end
		return nil
	end

	local function cancel()
		token += 1
		release()
		stopLines()
	end
	player.CharacterAdded:Connect(cancel)

	local function onRareShot(owner, rareId, origin, seconds)
		local play = PLAYS[rareId]
		if not play then
			return
		end
		local mine = owner == player
		local root = owner.Character and owner.Character:FindFirstChild("HumanoidRootPart")
		if not mine and (not root or (workspace.CurrentCamera.CFrame.Position - root.Position).Magnitude > 300) then
			return -- others see it only up close (note 17 §5)
		end
		if mine then
			cancel()
		end
		local my = token
		-- the cannon's name tag would sit over the close-ups, so it hides for the cutscene
		local myCannon = mine and workspace:FindFirstChild("MyCannon")
		local tag = myCannon and myCannon:FindFirstChild("Tag")
		if tag and tag:IsA("BillboardGui") and tag.Enabled then
			tag.Enabled = false
			task.delay(seconds + 0.5, function()
				tag.Enabled = true
			end)
		end
		local you = play(owner, seconds, mine, my)
		if mine then
			at(math.min(1.6, seconds * 0.5), my, hideCard) -- the title clears so the moment reads
			-- the world darkens for the last 5 frames before the shot (note 22: the inhale)
			at(seconds - 0.17, my, function()
				worldDim(-0.35, 0.15)
			end)
			-- hand the camera back a moment before the flight starts
			at(seconds - 0.05, my, release)
			if lingering then
				dropAura(lingering)
			end
			lingering = you
		end
	end
	task.spawn(function()
		local remote = Remotes:WaitForChild("RareShot", 60)
		if remote then
			remote.OnClientEvent:Connect(onRareShot)
		end
	end)

	-----------------------------------------------------------------------
	-- Impact frames (vault note 22, from Alex's reference clips): 1-3 frames
	-- of two-tone art, then the colour floods back over 6 frames.
	--   "burst": a white ink starburst behind the subject, the subject in black (Ref 1)
	--   "flat":  the whole screen one flat colour, black silhouettes (Ref 2)
	--   "ink":   black ink strokes on white, a new layout every frame (Ref 3)
	-- One flash a second at most. On Low Graphics a dark two-tone version: black
	-- silhouettes on the tier colour at 60%, no brightness spike.
	-----------------------------------------------------------------------
	local FRAME = 1 / 30
	local function inkLayout(look)
		local view = workspace.CurrentCamera.ViewportSize
		for i, img in ipairs(inks) do
			img.Image = i % 3 == 0 and TEX.Star4 or TEX.Slash
			img.ImageColor3 = Color3.new(0, 0, 0)
			local s = view.Y * (0.5 + math.random() * 0.7)
			img.Size = UDim2.fromOffset(s, s)
			img.Position = UDim2.fromOffset(math.random() * view.X, math.random() * view.Y)
			img.Rotation = math.random() * 360
			img.ImageTransparency = 0
			img.Visible = true
		end
	end
	local function impactFrame(subjects, look, style, frames)
		if os.clock() - lastFlash < 1 then
			return false
		end
		lastFlash = os.clock()
		local dark = lowGraphics()
		local hls = {}
		for _, s in ipairs(subjects) do
			if s and s.Parent then
				table.insert(hls, new("Highlight", {
					FillColor = Color3.new(0, 0, 0), FillTransparency = 0, OutlineColor = dark and look.Color or look.Core, OutlineTransparency = 0,
					DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Adornee = s, Parent = gui,
				}))
			end
		end
		grade.Enabled = true
		if dark then
			grade.Saturation, grade.Contrast, grade.Brightness, grade.TintColor = -0.6, 0.8, -0.35, look.Color:Lerp(Color3.new(0, 0, 0), 0.4)
		elseif style == "flat" then
			grade.Saturation, grade.Contrast, grade.Brightness, grade.TintColor = -1, 4, 0.8, look.Color
		elseif style == "ink" then
			grade.Saturation, grade.Contrast, grade.Brightness, grade.TintColor = -1, 4, 0.9, Color3.new(1, 1, 1)
		else -- burst
			grade.Saturation, grade.Contrast, grade.Brightness, grade.TintColor = -1, 1.5, 0.35, look.Core
			local s = subjects[1]
			local at = s and (s:IsA("Model") and s:GetBoundingBox().Position or s.Position)
			if at then
				local away = (at - workspace.CurrentCamera.CFrame.Position).Unit
				burstAt(CFrame.new(at + away * 12), {
					{ Texture = TEX.Star6, Color = ColorSequence.new(Color3.new(1, 1, 1)), LightEmission = 1, LightInfluence = 0, Brightness = 3,
						Size = NumberSequence.new(60), Lifetime = NumberRange.new(frames * FRAME + 0.05), Speed = NumberRange.new(0), Rotation = NumberRange.new(0, 360), ZOffset = -4, Count = 1 },
				})
			end
		end
		-- the frames themselves: ink re-drawn every frame
		local f = 0
		local conn
		conn = RunService.RenderStepped:Connect(function()
			f += 1
			if style == "ink" and not dark and f <= frames then
				inkLayout(look)
			end
			if f < frames then
				return
			end
			conn:Disconnect()
			inkOff()
			-- colour floods back over 6 frames (note 22 §2.3: never in one step)
			for _, hl in ipairs(hls) do
				hl.FillColor, hl.FillTransparency, hl.OutlineColor = look.Core, 0.4, look.Color
				TweenService:Create(hl, TweenInfo.new(6 * FRAME + 0.1), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
				Debris:AddItem(hl, 0.4)
			end
			grade.Saturation, grade.Contrast, grade.Brightness, grade.TintColor = 0.4, 0.5, dark and -0.2 or 0.15, look.Core
			local back = TweenService:Create(grade, TweenInfo.new(6 * FRAME, Enum.EasingStyle.Quad), { Saturation = 0, Contrast = 0, Brightness = 0, TintColor = Color3.new(1, 1, 1) })
			back.Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed then
					grade.Enabled = false
				end
			end)
			back:Play()
		end)
		return true
	end

	-- black lightning tendrils over a grey world for a few frames (Secret, Ref 2)
	local function tendrils(frames)
		if lowGraphics() then
			return
		end
		local view = workspace.CurrentCamera.ViewportSize
		dim.Enabled = true
		dim.Saturation = -1
		for i, img in ipairs(inks) do
			if i <= 5 then
				img.Image = TEX.Slash
				img.ImageColor3 = Color3.new(0, 0, 0)
				local s = view.Y * (0.6 + math.random() * 0.6)
				img.Size = UDim2.fromOffset(s * 1.6, s * 0.6)
				img.Position = UDim2.fromOffset(view.X * (0.2 + math.random() * 0.6), view.Y * (0.2 + math.random() * 0.6))
				img.Rotation = math.random() * 360
				img.ImageTransparency = 0.1
				img.Visible = true
			end
		end
		task.delay(frames * FRAME, function()
			inkOff()
			TweenService:Create(dim, TweenInfo.new(0.15), { Saturation = 0 }):Play()
		end)
	end

	-- a pillar of light rising from a point, fading over 0.8 s (Secret landing, Ref 2)
	local function pillar(pos, look, height)
		local p = part({ Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = look.Core, Transparency = 0.2, Size = Vector3.new(1, 10, 10), CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, rad(90)) })
		local glow = part({ Shape = Enum.PartType.Cylinder, Material = Enum.Material.ForceField, Color = look.Color, Transparency = 0.1, Size = Vector3.new(1, 18, 18), CFrame = p.CFrame })
		local v = new("NumberValue", { Value = 0, Parent = p })
		v.Changed:Connect(function(k)
			local h = math.max(height * k, 1)
			p.Size, glow.Size = Vector3.new(h, 10 * (1 - 0.3 * k), 10 * (1 - 0.3 * k)), Vector3.new(h, 18, 18)
			p.CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, rad(90))
			glow.CFrame = p.CFrame
		end)
		TweenService:Create(v, TweenInfo.new(0.25, Enum.EasingStyle.Exponential), { Value = 1 }):Play()
		task.delay(0.35, function()
			TweenService:Create(p, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { Transparency = 1 }):Play()
			TweenService:Create(glow, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { Transparency = 1 }):Play()
		end)
		Debris:AddItem(p, 1.3)
		Debris:AddItem(glow, 1.3)
	end
	-- a dome of light that blooms over a point, then pops into petals (Divine landing, Ref 3)
	local function dome(pos, look, radius)
		local d = part({ Shape = Enum.PartType.Ball, Material = Enum.Material.ForceField, Color = look.Color, Transparency = 0, Size = Vector3.one * 2, CFrame = CFrame.new(pos) })
		TweenService:Create(d, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), { Size = Vector3.one * radius * 2 }):Play()
		task.delay(0.6, function()
			TweenService:Create(d, TweenInfo.new(0.2), { Transparency = 1 }):Play()
			burstAt(CFrame.new(pos + Vector3.new(0, radius * 0.4, 0)), {
				{ Texture = TEX.Puff, Color = ColorSequence.new(look.Core, look.Color), LightEmission = 0.3, LightInfluence = 0.2,
					Squash = NumberSequence.new(1.2), Size = NumberSequence.new(1.6, 1), Transparency = fadeSeq(0, 0.2), Lifetime = NumberRange.new(1.5, 2.5),
					Speed = NumberRange.new(radius * 0.6, radius * 1.2), SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, -6, 0), Drag = 1.5,
					Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-180, 180), Count = 40 },
			})
		end)
		Debris:AddItem(d, 1)
	end
	local function groundAt(pos)
		floorRay.FilterDescendantsInstances = { fx, player.Character }
		local hit = workspace:Raycast(pos + Vector3.new(0, 60, 0), Vector3.new(0, -160, 0), floorRay)
		return hit and hit.Position or pos
	end
	-- the landing (note 22 §4): every tier lands with an inhale and rings; Secret adds a pillar and its
	-- second flash, Divine a white starburst, a bloom dome and petals; then the world comes back calm
	local function landing(rareId, look, pos)
		local spot = groundAt(pos)
		local inhale = rareId == "Mythic" and 3 or rareId == "Secret" and 5 or 4
		worldDim(-0.35, inhale * FRAME)
		task.delay(inhale * FRAME, function()
			if rareId == "Mythic" then
				crater(spot, 12, 2.5)
				shockwave(spot, look, 10)
				task.delay(2 * FRAME, function()
					shockwave(spot, look, 7)
				end)
				fxPlay("Stars", CFrame.new(spot + Vector3.new(0, 3, 0)), 3, look, 0.5)
			elseif rareId == "Secret" then
				impactFrame({}, look, "flat", 2)
				for i = 0, 2 do
					task.delay(i * 0.06, function()
						shockwave(spot, look, 9 + i * 5)
					end)
				end
				pillar(spot, look, 120)
				fxPlay("HolyAura", CFrame.new(spot), 4, look, 0.8)
				shake(0.5, 0.3)
			else
				impactFrame({}, look, "burst", 2)
				fxPlay("Explosion", CFrame.new(spot + Vector3.new(0, 4, 0)), 3, look, 0.2)
				task.delay(0.2, function()
					dome(spot, look, 18)
				end)
				shockwave(spot, look, 14)
				shake(0.5, 0.3)
			end
			-- calm: the world comes back over 0.3-0.5 s
			worldDim(0, rareId == "Divine" and 0.5 or 0.3)
		end)
	end

	-----------------------------------------------------------------------
	-- The rare flight: the release (impact frame, focus lines, muzzle
	-- blast), a comet of flame on the ball, speed streaks while it cruises
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
	local function muzzleBlast(pos, look)
		local face = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, rad(90), 0)
		ringAt(face + dir * 1, look.Core, 3, 18 + look.Rank * 4, 0.35, 0.4)
		ringAt(face + dir * 5, look.Color, 2, 14 + look.Rank * 3, 0.4, 0.3)
		ringAt(face + dir * 10, look.Dark, 1.5, 10 + look.Rank * 2, 0.4, 0.25)
		for i = 1, 10 + look.Rank * 5 do
			local spread = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 0.7
			tongue(pos + spread, (dir + spread).Unit, 7 + math.random() * 6, 1.6, i % 3 == 0 and look.Core or look.Color, 0.1, 0.22 + math.random() * 0.1)
		end
		burstAt(CFrame.lookAt(pos, pos - dir), { -- Front is -Z: face the shot
			{ Texture = TEX.Star6, Color = ColorSequence.new(look.Core), LightEmission = 1, LightInfluence = 0, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(0.25, 16 + look.Rank * 4), NumberSequenceKeypoint.new(1, 0) }), Lifetime = NumberRange.new(0.12), Speed = NumberRange.new(0), Rotation = NumberRange.new(0, 360), ZOffset = 2, Count = 1 },
			{ Texture = TEX.Streak, Orientation = Enum.ParticleOrientation.VelocityParallel, Color = ColorSequence.new(look.Core, look.Color), LightEmission = 1, LightInfluence = 0, Size = NumberSequence.new(1.2, 0), Lifetime = NumberRange.new(0.2, 0.4), Speed = NumberRange.new(40, 70), Drag = 4, SpreadAngle = Vector2.new(25, 25), EmissionDirection = Enum.NormalId.Front, Count = 20 + look.Rank * 5 },
			{ Texture = TEX.CelPuff, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = Enum.ParticleFlipbookMode.OneShot, Color = ColorSequence.new(Color3.fromRGB(245, 242, 235)), LightEmission = 0, LightInfluence = 0.5, Size = NumberSequence.new(4, 9), Lifetime = NumberRange.new(0.7, 1), Speed = NumberRange.new(8, 16), Drag = 3, SpreadAngle = Vector2.new(35, 35), EmissionDirection = Enum.NormalId.Front, Rotation = NumberRange.new(0, 360), Count = 8 },
		})
		local att = new("Attachment", { Parent = workspace.Terrain })
		att.WorldPosition = pos
		local light = new("PointLight", { Color = look.Color, Brightness = 8, Range = 24, Shadows = false, Parent = att })
		TweenService:Create(light, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Brightness = 0 }):Play()
		Debris:AddItem(att, 0.5)
	end
	-- the ball in flight (Alex, Oct 31: "actual vfx from the pack", not pill shapes): the pack's fireball
	-- and projectile trail ride the ball, facing the way it flies; Secret adds crackle, Divine stars
	local function comet(ball, look, mine, duration)
		local last, heading = ball.Position, dir
		local cf = CFrame.lookAt(last, last + dir)
		local track
		track = RunService.Heartbeat:Connect(function()
			if not ball.Parent then
				track:Disconnect()
				return
			end
			local p = ball.Position
			local v = p - last
			if v.Magnitude > 0.05 then
				heading = heading:Lerp(v.Unit, 0.35).Unit
			end
			last = p
			cf = CFrame.lookAt(p, p + heading)
		end)
		task.delay(duration + 1, function()
			track:Disconnect()
		end)
		local function follow()
			return ball.Parent and cf or nil
		end
		fxPlay("Ball", follow, 1 + 0.2 * look.Rank, look, duration)
		fxPlay("Projectile", follow, 0.9 + 0.15 * look.Rank, look, duration)
		if look.Rank >= 3 then
			fxPlay("Stars", follow, 1.6, look, duration)
		end
		if mine then
			-- a rim-lit outline on the ball (Ref 1 and 3: the hero reads against the sky)
			local hl = new("Highlight", { FillTransparency = 1, OutlineColor = look.Color, OutlineTransparency = 0.2, DepthMode = Enum.HighlightDepthMode.Occluded, Adornee = ball, Parent = ball })
			TweenService:Create(hl, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { OutlineTransparency = 0.6 }):Play()
			if look.Rank >= 2 and not lowGraphics() then
				-- crackle left hanging in the air behind the ball
				task.spawn(function()
					local t0 = os.clock()
					while ball.Parent and os.clock() - t0 < duration * 0.85 do
						fxPlay("Lightning2", CFrame.new(ball.Position - heading * 3), 2.5, look, 0.12)
						task.wait(0.28)
					end
				end)
			end
		end
	end

	Remotes.LaunchPlayer.OnClientEvent:Connect(function(owner, origin, distance, duration, cash, rareId)
		local look = rareId and LOOKS[rareId]
		if not look then
			return -- normal shots stay clean (vault note 17 §1)
		end
		local mine = owner == player
		if mine then
			release() -- the flight takes the camera now
		end
		task.defer(function()
			local ball = findBall(ctx.RareMuzzle(rareId) or origin)
			local start = ball and ball.Position or origin
			if not mine and (workspace.CurrentCamera.CFrame.Position - start).Magnitude > 400 then
				if ball then
					comet(ball, look, false, duration)
				end
				return
			end
			muzzleBlast(start, look)
			fxPlay("Shoot", CFrame.lookAt(start, start + dir), 3 + look.Rank, look)
			fxPlay("Flash", CFrame.new(start), 2 + look.Rank, look, 0.2)
			if rareId == "Secret" then
				fxPlay("Explosion", CFrame.new(start), 4, nil, 0.3)
			end
			if ball then
				comet(ball, look, mine, duration)
			end
			if not mine then
				return
			end
			Kit.playSound("RareBlast")
			-- the release (note 22 §4): two-tone impact frames, then the colour floods back, rings on the water
			local cannon = workspace:FindFirstChild("MyCannon")
			local char = player.Character
			if rareId == "Mythic" then
				impactFrame({ cannon or ball }, look, "burst", 1)
			elseif rareId == "Secret" then
				if impactFrame({ grandCannon(), char }, look, "flat", 2) then
					task.delay(2 * FRAME, function()
						tendrils(4)
					end)
				end
			else
				if impactFrame({ cannon or ball, char }, look, "ink", 3) then
					-- then 3 frames of dark rim silhouette with a sky-blue edge
					task.delay(3 * FRAME, function()
						worldDim(-0.3, 0)
						for _, s in ipairs({ cannon, char }) do
							if s then
								local hl = new("Highlight", { FillColor = Color3.new(0, 0, 0), FillTransparency = 0, OutlineColor = look.Dark, OutlineTransparency = 0, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Adornee = s, Parent = gui })
								TweenService:Create(hl, TweenInfo.new(0.2), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
								Debris:AddItem(hl, 0.3)
							end
						end
					end)
				end
			end
			hitStop(0.06 + 0.02 * look.Rank, false) -- the flight camera is cutting in: freeze the effects, not the view
			task.delay(0.12, function()
				worldDim(0, 0.3)
			end)
			local water = groundAt(start + dir * 6)
			shockwave(water, look, 8)
			task.delay(2 * FRAME, function()
				shockwave(water, look, 6)
			end)
			local sp = workspace.CurrentCamera:WorldToViewportPoint(start)
			focusLines(Vector2.new(sp.X, sp.Y), look, rareId == "Divine" and 0.6 or 0.3, false)
			shake(0.5 + look.Rank * 0.25, 0.35 + look.Rank * 0.05)
			skyBack(1.2)
			if ball then
				task.delay(0.35, function()
					if ball.Parent then
						flightStreaks(ball, duration, look)
					end
				end)
			end
			-- the landing beat where the server put the ball
			task.delay(duration, function()
				landing(rareId, look, origin + dir * distance)
			end)
			-- the angel cannon turns back after the landing; your aura settles to a glow for a while
			task.delay(duration + Config.RETURN_DELAY + 0.5, restoreCannon)
			local rig = lingering
			if rig then
				task.delay(duration + 0.5, function()
					if auras[rig] then
						setPower(rig, 0.25)
						dropAura(rig, 30)
					end
				end)
			end
		end)
	end)

	-- Low Graphics changed: thin any live aura
	State.Changed:Connect(function()
		for rig in pairs(auras) do
			setPower(rig, rig.Power)
		end
	end)
end
