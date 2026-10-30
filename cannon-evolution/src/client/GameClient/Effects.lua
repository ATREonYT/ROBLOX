--[[
	Effects  (ModuleScript)
	World-side visuals: training-station shot animation, the launch, pets
	following players, and applying Settings (music, other players, pets,
	low graphics).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Icons = require(ReplicatedStorage:WaitForChild("Icons"))

return function(ctx)
	local Kit, Config, State = ctx.Kit, ctx.Config, ctx.State
	local new = Kit.new
	local player = ctx.Player
	local stations = workspace:WaitForChild("TrainingStations")

	-----------------------------------------------------------------------
	-- Training: leave on jump
	-----------------------------------------------------------------------
	Remotes.TrainingState.OnClientEvent:Connect(function(stationId)
		State.Training = stationId
		ctx.OnTrainingChanged(stationId)
	end)
	UserInputService.JumpRequest:Connect(function()
		if State.Training then
			ctx.Request("StopTraining")
		end
	end)

	-----------------------------------------------------------------------
	-- Shot animation
	-----------------------------------------------------------------------
	local recoiling = {}
	local function recoil(station)
		local cannon = station:FindFirstChild("Cannon")
		local muzzle = station:FindFirstChild("Muzzle")
		if not (cannon and muzzle) or recoiling[station] then
			return
		end
		recoiling[station] = true
		local home = cannon:GetPivot()
		local back = home - muzzle.CFrame.LookVector * 0.8
		local alpha = Instance.new("NumberValue")
		alpha.Changed:Connect(function(a)
			cannon:PivotTo(home:Lerp(back, a))
		end)
		local out = TweenService:Create(alpha, TweenInfo.new(0.06), { Value = 1 })
		local ret = TweenService:Create(alpha, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Value = 0 })
		out.Completed:Connect(function()
			ret:Play()
		end)
		ret.Completed:Connect(function()
			cannon:PivotTo(home)
			alpha:Destroy()
			recoiling[station] = nil
		end)
		out:Play()
	end

	local function burst(parent, props)
		local att = Instance.new("Attachment")
		if typeof(parent) == "Vector3" then
			att.WorldPosition = parent
			att.Parent = workspace.Terrain
		else
			att.Parent = parent
		end
		local count = props.Count or 12
		props.Count = nil -- not a ParticleEmitter property
		local pe = new("ParticleEmitter", props)
		pe.Enabled = false
		pe.Parent = att
		pe:Emit(count)
		Debris:AddItem(att, 1.5)
		return att
	end

	local function floatingText(position, text, color, big)
		local anchor = new("Part", {
			Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
			Transparency = 1, Size = Vector3.one * 0.2, Position = position, Parent = workspace,
		})
		local bb = new("BillboardGui", { Size = UDim2.fromOffset(240, 70), AlwaysOnTop = true, StudsOffset = Vector3.new(0, 2, 0), Parent = anchor })
		local t = Kit.text({ Text = text, Size = big and 56 or 40, Color = color, Parent = bb })
		-- pop in big, then settle
		local pop = new("UIScale", { Scale = big and 1.8 or 1.5, Parent = t })
		TweenService:Create(pop, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		TweenService:Create(bb, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { StudsOffset = Vector3.new(math.random(-15, 15) / 10, 6, 0) }):Play()
		task.delay(0.5, function()
			TweenService:Create(t, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			TweenService:Create(t:FindFirstChildOfClass("UIStroke"), TweenInfo.new(0.4), { Transparency = 1 }):Play()
		end)
		Debris:AddItem(anchor, 1)
	end

	-- the booth's glow colour (BuildWorld1 sets it), so every booth's shots look like that booth
	local function accentOf(station)
		return station:GetAttribute("Accent") or Color3.fromRGB(255, 220, 80)
	end

	-- the booth light swells on a hit; at most once a second (kid-safe flashing limit)
	local lastPulse = {}
	local function pulseBooth(station)
		local booth = station:FindFirstChild("Booth")
		local lamp = booth and booth:FindFirstChild("Glow")
		local light = lamp and lamp:FindFirstChildOfClass("PointLight")
		if not light or os.clock() - (lastPulse[station.Name] or 0) < 1 then
			return
		end
		lastPulse[station.Name] = os.clock()
		local base = light:GetAttribute("Base") or light.Brightness
		light:SetAttribute("Base", base)
		light.Brightness = base * 1.8
		TweenService:Create(light, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Brightness = base }):Play()
	end

	-- a flat ring that grows and fades on the target face
	local function shockwave(center, color)
		local ring = new("Part", {
			Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 1.5, 1.5), Color = color, Material = Enum.Material.Neon,
			Transparency = 0.2, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
			CFrame = center.CFrame * CFrame.new(0, 0, -0.4) * CFrame.Angles(0, math.rad(90), 0), Parent = workspace,
		})
		TweenService:Create(ring, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Size = Vector3.new(0.1, 7, 7), Transparency = 1 }):Play()
		Debris:AddItem(ring, 0.35)
	end

	local function hitTarget(target, position, crit, color)
		local center = target:FindFirstChild("Center")
		if center and not target:GetAttribute("Shaking") then
			target:SetAttribute("Shaking", true)
			local home = target:GetPivot()
			target:PivotTo(home - center.CFrame.LookVector * 0.4)
			task.delay(0.08, function()
				target:PivotTo(home)
				target:SetAttribute("Shaking", nil)
			end)
		end
		burst(position, {
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Color = ColorSequence.new(crit and Color3.fromRGB(255, 80, 255) or color),
			Size = NumberSequence.new(crit and 1 or 0.6, 0),
			Lifetime = NumberRange.new(0.3, 0.5),
			Speed = NumberRange.new(10, crit and 30 or 20),
			SpreadAngle = Vector2.new(180, 180),
			LightEmission = 1,
			Count = crit and 40 or 20,
		})
	end

	local function fireBall(station, isMine, gain, crit)
		local muzzle = station:FindFirstChild("Muzzle")
		local target = station:FindFirstChild("Target")
		local center = target and target:FindFirstChild("Center")
		if not (muzzle and center) then
			return
		end
		recoil(station)
		local accent = accentOf(station)
		local att = burst(muzzle, {
			Texture = "rbxasset://textures/particles/smoke_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(255, 240, 200), Color3.fromRGB(120, 120, 120)),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2.5) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(0.3, 0.6),
			Speed = NumberRange.new(6, 12),
			SpreadAngle = Vector2.new(25, 25),
			EmissionDirection = Enum.NormalId.Front,
			Count = 12,
		})
		local light = new("PointLight", { Color = accent, Brightness = 6, Range = 12, Parent = att })
		TweenService:Create(light, TweenInfo.new(0.2), { Brightness = 0 }):Play()
		if isMine then
			Kit.playSound("Shot")
		end

		local ball = new("Part", {
			Shape = Enum.PartType.Ball, Size = Vector3.one * 1.2,
			Color = crit and Color3.fromRGB(200, 60, 255) or accent,
			Material = Enum.Material.Neon,
			Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
			Parent = workspace,
		})
		new("Trail", {
			Attachment0 = new("Attachment", { Position = Vector3.new(0, 0.4, 0), Parent = ball }),
			Attachment1 = new("Attachment", { Position = Vector3.new(0, -0.4, 0), Parent = ball }),
			Lifetime = 0.2,
			Color = ColorSequence.new(crit and Color3.fromRGB(255, 120, 255) or accent),
			LightEmission = 1,
			WidthScale = NumberSequence.new(1, 0),
			Transparency = NumberSequence.new(0.2, 1),
			Parent = ball,
		})
		local p0, p2 = muzzle.Position, center.Position
		local p1 = (p0 + p2) / 2 + Vector3.new(0, (p2 - p0).Magnitude * 0.25, 0)
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local a = math.min((os.clock() - t0) / 0.35, 1)
			ball.Position = (1 - a) ^ 2 * p0 + 2 * (1 - a) * a * p1 + a ^ 2 * p2
			if a >= 1 then
				conn:Disconnect()
				ball:Destroy()
				hitTarget(target, p2, crit, accent)
				shockwave(center, crit and Color3.fromRGB(255, 120, 255) or accent)
				if isMine then
					pulseBooth(station)
				end
				if isMine then
					floatingText(p2, (crit and "CRIT! +" or "+") .. Config.Format(gain) .. " ⚡", crit and Color3.fromRGB(255, 90, 255) or Kit.Colors.Yellow, crit)
				end
			end
		end)
	end

	Remotes.TrainingShot.OnClientEvent:Connect(function(shooter, stationId, gain, crit)
		local station = stations:FindFirstChild("Station_" .. stationId)
		if not station then
			return
		end
		local isMine = shooter == player
		if not isMine and (workspace.CurrentCamera.CFrame.Position - station:GetPivot().Position).Magnitude > 150 then
			return
		end
		fireBall(station, isMine, gain, crit)
	end)

	-----------------------------------------------------------------------
	-- Rebirth signs over the training areas: icon, LOCKED / UNLOCKED ribbon
	-----------------------------------------------------------------------
	local rebirthSigns = {}
	for _, station in ipairs(stations:GetChildren()) do
		local sign = station:FindFirstChild("RebirthSign")
		local card = sign and sign:FindFirstChild("Gui") and sign.Gui:FindFirstChild("Card")
		if card then
			local icon = card:FindFirstChild("Icon")
			local name = icon and icon:GetAttribute("Icon")
			if name and Kit.hasImage(name) then
				icon.Image = Icons[name]
				icon.Fallback.Visible = false
			end
			table.insert(rebirthSigns, { Sign = sign, Status = card:FindFirstChild("Status"), Icon = icon })
		end
	end
	local lastUnlock = ""
	State.Changed:Connect(function(what)
		local data = what == nil and State.Data
		if not data then
			return
		end
		local key = data.Rebirths .. tostring(State.Passes.VIP)
		if key == lastUnlock then
			return
		end
		lastUnlock = key
		for _, s in ipairs(rebirthSigns) do
			local pass = s.Sign:GetAttribute("Pass")
			local open = if pass then State.Passes[pass] == true else data.Rebirths >= (s.Sign:GetAttribute("Rebirths") or 0)
			if s.Status then
				s.Status.BackgroundColor3 = open and Color3.fromRGB(70, 210, 90) or Color3.fromRGB(235, 60, 60)
				s.Status.Text.Text = open and "✅ UNLOCKED" or "🔒 LOCKED"
			end
			-- the over-booth sign has no ribbon: a locked booth's icon is dimmed instead
			if s.Icon and not s.Status then
				s.Icon.ImageColor3 = open and Color3.new(1, 1, 1) or Color3.fromRGB(120, 120, 135)
			end
		end
	end)

	-----------------------------------------------------------------------
	-- Launch
	-----------------------------------------------------------------------
	-- Like Stone Skipping: the Grand Cannon fires a cannonball that skims
	-- the water down the track. The camera follows it low, a big metres
	-- counter counts up, each skip pops some cash, and passing through an
	-- area's see-through border shows its name.
	local flightGui = new("ScreenGui", { Name = "Flight", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 5, Enabled = false, Parent = player.PlayerGui })
	new("UIScale", { Parent = flightGui })
	local counter = Kit.text({ Text = "0 m", Size = 72, Color = Kit.Colors.Yellow, StrokeSize = 5, FrameSize = UDim2.fromOffset(600, 90), Position = UDim2.new(0.5, 0, 0, 96), Anchor = Vector2.new(0.5, 0), ZIndex = 2, Parent = flightGui })
	new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 245, 140), Color3.fromRGB(255, 180, 40)), Rotation = 90, Parent = counter })
	local counterScale = new("UIScale", { Parent = counter })
	local banner = Kit.text({ Text = "", Size = 46, FrameSize = UDim2.fromOffset(800, 60), Position = UDim2.new(0.5, 0, 0, 180), Anchor = Vector2.new(0.5, 0), ZIndex = 2, Parent = flightGui })
	local bannerScale = new("UIScale", { Scale = 0, Parent = banner })
	local function commas(n)
		local text = tostring(n)
		repeat
			local k
			text, k = text:gsub("^(%d+)(%d%d%d)", "%1,%2")
		until k == 0
		return text
	end
	local function fitGui()
		local cam = workspace.CurrentCamera
		flightGui.UIScale.Scale = math.min(cam.ViewportSize.X / 1280, cam.ViewportSize.Y / 720)
	end
	local function cashPop(amount)
		local pop = Kit.text({ Text = "+" .. Config.Format(amount) .. " 💵", Size = 30, Color = Kit.Colors.Green, FrameSize = UDim2.fromOffset(240, 40), Position = UDim2.new(0.5, math.random(-140, 140), 0.55, 0), Anchor = Vector2.new(0.5, 0.5), ZIndex = 3, Parent = flightGui })
		TweenService:Create(pop, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { Position = pop.Position - UDim2.fromOffset(0, 90), TextTransparency = 1 }):Play()
		TweenService:Create(pop.UIStroke, TweenInfo.new(0.9), { Transparency = 1 }):Play()
		Debris:AddItem(pop, 1)
	end

	-- the area borders along the track (built in workspace.AreaBorders)
	local function getBorders(origin, dir)
		local list = {}
		local folder = workspace:FindFirstChild("AreaBorders")
		for _, b in ipairs(folder and folder:GetChildren() or {}) do
			if b:IsA("BasePart") then
				table.insert(list, { At = (b.Position - origin):Dot(dir), Name = b:GetAttribute("AreaName") or b.Name, Color = b.Color })
			end
		end
		table.sort(list, function(x, y)
			return x.At < y.At
		end)
		return list
	end

	-- height of the water along the track
	local waterParams = RaycastParams.new()
	waterParams.FilterType = Enum.RaycastFilterType.Include
	local function waterAt(pos, fallback)
		local mapRoot = workspace:FindFirstChild("map1b")
		local ocean = mapRoot and mapRoot:FindFirstChild("Ocean", true)
		if not ocean then
			return fallback
		end
		waterParams.FilterDescendantsInstances = { ocean }
		local hit = workspace:Raycast(Vector3.new(pos.X, pos.Y + 300, pos.Z), Vector3.new(0, -600, 0), waterParams)
		return hit and hit.Position.Y or fallback
	end

	local BALL_RADIUS = 1.4
	local function splash(pos, big)
		local ring = new("Part", {
			Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
			Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = Color3.fromRGB(220, 245, 255),
			Size = Vector3.new(0.2, 2, 2), Transparency = 0.25,
			CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
			Parent = workspace,
		})
		local size = big and 22 or 9
		TweenService:Create(ring, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Size = Vector3.new(0.2, size, size), Transparency = 1 }):Play()
		local emitter = new("ParticleEmitter", {
			Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(Color3.fromRGB(230, 248, 255)),
			Speed = NumberRange.new(10, 20), SpreadAngle = Vector2.new(35, 35), Lifetime = NumberRange.new(0.35, 0.6),
			Size = NumberSequence.new(1.1, 0), Acceleration = Vector3.new(0, -70, 0), EmissionDirection = Enum.NormalId.Right,
			Rate = 0, Parent = ring,
		})
		emitter:Emit(big and 36 or 12)
		Debris:AddItem(ring, 0.8)
	end

	-- the ball's final landing: a tall foamy splash and three waves rolling out over the water (Alex, Oct 30).
	-- Plain white parts, no neon, so nothing flashes
	local function bigSplash(pos)
		for i = 0, 2 do
			task.delay(i * 0.22, function()
				local wave = new("Part", {
					Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
					Shape = Enum.PartType.Cylinder, Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(235, 250, 255),
					Size = Vector3.new(0.35, 4, 4), Transparency = 0.15,
					CFrame = CFrame.new(pos + Vector3.new(0, 0.05 * i, 0)) * CFrame.Angles(0, 0, math.rad(90)),
					Parent = workspace,
				})
				local size = 30 - i * 6
				TweenService:Create(wave, TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Size = Vector3.new(0.12, size, size), Transparency = 1,
				}):Play()
				Debris:AddItem(wave, 1.4)
			end)
		end
		local column = new("Part", {
			Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1,
			Size = Vector3.new(3, 0.2, 3), CFrame = CFrame.new(pos), Parent = workspace,
		})
		-- foam shooting up and falling back
		new("ParticleEmitter", {
			Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromRGB(245, 252, 255)),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5), NumberSequenceKeypoint.new(1, 4.5) }),
			Speed = NumberRange.new(22, 34), SpreadAngle = Vector2.new(14, 14), Lifetime = NumberRange.new(0.8, 1.2),
			Acceleration = Vector3.new(0, -55, 0), EmissionDirection = Enum.NormalId.Top, Rate = 0, Parent = column,
		}):Emit(26)
		-- droplets flying out to the sides
		new("ParticleEmitter", {
			Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(Color3.fromRGB(220, 245, 255)),
			Size = NumberSequence.new(1.2, 0), Speed = NumberRange.new(16, 28), SpreadAngle = Vector2.new(60, 60),
			Lifetime = NumberRange.new(0.6, 1), Acceleration = Vector3.new(0, -70, 0), EmissionDirection = Enum.NormalId.Top,
			Rate = 0, Parent = column,
		}):Emit(40)
		Debris:AddItem(column, 2.5)
	end

	local function popBanner(text, color)
		banner.Text = text
		banner.TextColor3 = color
		bannerScale.Scale = 0
		TweenService:Create(bannerScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		task.delay(1.6, function()
			if banner.Text == text then
				TweenService:Create(bannerScale, TweenInfo.new(0.25), { Scale = 0 }):Play()
			end
		end)
	end

	local function setSideMenu(visible)
		local main = player.PlayerGui:FindFirstChild("MainUI")
		local side = main and main:FindFirstChild("Side", true)
		if side then
			side.Visible = visible
		end
	end

	local myFlight = nil -- Heartbeat connection for my own throw
	local function endFlight()
		if myFlight then
			myFlight:Disconnect()
			myFlight = nil
		end
		local cam = workspace.CurrentCamera
		cam.CameraType = Enum.CameraType.Custom
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			cam.CameraSubject = hum
		end
		flightGui.Enabled = false
		setSideMenu(true)
	end
	-- the area walls only show while you fly: from the lobby they stacked up behind your cannon and
	-- their names printed on top of the cannon's sign (play-test, Oct 30)
	local function showBorders(on)
		local folder = workspace:FindFirstChild("AreaBorders")
		for _, b in ipairs(folder and folder:GetChildren() or {}) do
			if b:IsA("BasePart") then
				b.LocalTransparencyModifier = on and 0 or 1
				for _, g in ipairs(b:GetChildren()) do
					if g:IsA("SurfaceGui") then
						g.Enabled = on
					end
				end
			end
		end
	end
	task.spawn(function()
		workspace:WaitForChild("AreaBorders", 30)
		showBorders(player:GetAttribute("Launching") == true)
	end)
	player:GetAttributeChangedSignal("Launching"):Connect(function()
		local on = player:GetAttribute("Launching") == true
		showBorders(on)
		if not on then
			endFlight()
		end
	end)

	-----------------------------------------------------------------------
	-- My cannon: the equipped cannon stands beside the Launch Zone, waiting
	-- to fire. Rebirth unlocks auto-equip the best one; the Cannons panel
	-- changes it. Only this player sees their own cannon here.
	-----------------------------------------------------------------------
	-- the floor at the start of the water, behind the Launch Zone (BuildWorld1 places MyCannonSpot)
	local spotPart = workspace:FindFirstChild("MyCannonSpot")
	local MY_CANNON_SPOT = spotPart and spotPart.Position or Vector3.new(-145, 8.45, -144.25)
	local MY_CANNON_HEIGHT = 9
	local myCannon = { Model = nil, Id = nil, Home = nil, Muzzle = nil }

	local function placeMyCannon(id)
		local info = Config.GetCannon(id)
		local folder = ReplicatedStorage:FindFirstChild("Cannons")
		local source = info and folder and folder:FindFirstChild(info.Model)
		if myCannon.Model then
			myCannon.Model:Destroy()
			myCannon.Model = nil
		end
		myCannon.Id = id
		if not source then
			return
		end
		local model = source:Clone()
		model.Name = "MyCannon"
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanTouch = false
			elseif d:IsA("Script") or d:IsA("LocalScript") then
				d:Destroy()
			end
		end
		local dir = Config.LAUNCH_DIRECTION.Unit
		-- imported cannons point their barrel along +Z: turn +Z to the launch direction
		model:PivotTo(CFrame.lookAt(Vector3.zero, -dir))
		local _, size = model:GetBoundingBox()
		model:ScaleTo(model:GetScale() * MY_CANNON_HEIGHT / size.Y)
		local cf, scaled = model:GetBoundingBox()
		local lift = MY_CANNON_SPOT - Vector3.new(cf.X, cf.Y - scaled.Y / 2, cf.Z)
		model:PivotTo(model:GetPivot() + lift)
		myCannon.Home = model:GetPivot()

		-- where the ball leaves: the bore if the model has one, else the front of the barrel
		local bore = model:FindFirstChild("Bore", true) or model:FindFirstChild("MuzzleRing", true)
		if bore and bore:IsA("BasePart") then
			myCannon.Muzzle = myCannon.Home:ToObjectSpace(CFrame.new(bore.Position + dir * (bore.Size.Magnitude / 2)))
		else
			local box = model:GetBoundingBox()
			myCannon.Muzzle = myCannon.Home:ToObjectSpace(CFrame.new(box.Position + dir * scaled.X / 2 + Vector3.new(0, scaled.Y * 0.2, 0)))
		end

		local tag = new("BillboardGui", { Name = "Tag", Size = UDim2.fromOffset(220, 56), StudsOffsetWorldSpace = Vector3.new(0, scaled.Y / 2 + 2.5, 0), AlwaysOnTop = false, MaxDistance = 90, LightInfluence = 0, Parent = model })
		tag.Adornee = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
		Kit.text({ Text = info.Id .. " Cannon", Size = 26, FrameSize = UDim2.new(1, 0, 0, 30), Parent = tag })
		Kit.text({ Text = "x" .. info.Mult .. " ⚡ Power", Size = 20, Color = Kit.Colors.Yellow, FrameSize = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 30), Parent = tag })
		model.Parent = workspace

		-- a little pop when a new cannon arrives
		local home = myCannon.Home
		model:PivotTo(home + Vector3.new(0, 6, 0))
		local drop = Instance.new("NumberValue")
		drop.Value = 6
		drop.Parent = model -- tweens only run on values in the DataModel
		drop.Changed:Connect(function(v)
			if model.Parent then
				model:PivotTo(home + Vector3.new(0, v, 0))
			end
		end)
		local tween = TweenService:Create(drop, TweenInfo.new(0.5, Enum.EasingStyle.Bounce), { Value = 0 })
		tween.Completed:Connect(function()
			drop:Destroy()
		end)
		tween:Play()
		task.delay(0.8, function() -- never left hanging in the air
			if model.Parent and myCannon.Model == model then
				drop:Destroy()
				model:PivotTo(home)
			end
		end)
		myCannon.Model = model
	end

	-- the ball's start point and a recoil / flash / smoke when it fires
	local function fireMyCannon()
		local model = myCannon.Model
		if not (model and model.Parent and myCannon.Home) then
			return nil
		end
		local dir = Config.LAUNCH_DIRECTION.Unit
		local home = myCannon.Home
		local muzzle = (home * myCannon.Muzzle).Position

		local kick = Instance.new("NumberValue")
		kick.Parent = model
		kick.Changed:Connect(function(v)
			if model.Parent then
				model:PivotTo(home - dir * v)
			end
		end)
		local back = TweenService:Create(kick, TweenInfo.new(0.07, Enum.EasingStyle.Quad), { Value = 1.6 })
		back.Completed:Connect(function()
			local settle = TweenService:Create(kick, TweenInfo.new(0.5, Enum.EasingStyle.Elastic), { Value = 0 })
			settle.Completed:Connect(function()
				kick:Destroy()
			end)
			settle:Play()
		end)
		back:Play()
		task.delay(1, function()
			if kick.Parent then
				kick:Destroy()
				model:PivotTo(home)
			end
		end)

		local flash = new("Part", {
			Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
			Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 200, 90),
			Size = Vector3.one * 2, CFrame = CFrame.new(muzzle), Parent = workspace,
		})
		new("PointLight", { Color = Color3.fromRGB(255, 180, 80), Range = 18, Brightness = 4, Parent = flash })
		TweenService:Create(flash, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { Size = Vector3.one * 7, Transparency = 1 }):Play()
		local smoke = new("ParticleEmitter", {
			Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromRGB(235, 235, 235)),
			Speed = NumberRange.new(4, 10), SpreadAngle = Vector2.new(30, 30), Lifetime = NumberRange.new(0.8, 1.3),
			Size = NumberSequence.new(1.5, 5), Transparency = NumberSequence.new(0.3, 1), Acceleration = Vector3.new(0, 4, 0),
			EmissionDirection = Enum.NormalId.Front, Rate = 0, Parent = flash,
		})
		smoke:Emit(18)
		Debris:AddItem(flash, 1.5)
		return muzzle
	end

	local lastCannonKey = ""
	State.Changed:Connect(function(what)
		local data = what == nil and State.Data
		if not data then
			return
		end
		local key = tostring(data.EquippedCannon)
		if key == lastCannonKey and myCannon.Model and myCannon.Model.Parent then
			return
		end
		lastCannonKey = key
		placeMyCannon(data.EquippedCannon)
	end)

	Remotes.LaunchPlayer.OnClientEvent:Connect(function(owner, origin, distance, duration, cash)
		local mine = owner == player
		local settings = State.Data and State.Data.Settings
		if not mine and settings and settings.ShowPlayers == false then
			return
		end
		local dir = Config.LAUNCH_DIRECTION.Unit
		-- my shots leave my cannon's muzzle; land on the same spot the server chose
		local landing = origin + dir * distance
		local reported = distance -- what the counter counts up to
		local muzzle = mine and fireMyCannon()
		if muzzle then
			origin = muzzle
			distance = math.max((landing - origin):Dot(dir), 30)
		end
		local function pointAt(dist)
			return origin + dir * dist
		end

		-- skips: { from, to, height, yFrom, yTo }. A big arc out of the
		-- cannon, then shorter and lower skips, then a slide to a stop.
		local hops = {}
		local first = math.min(distance, math.max(distance * Config.SKIP_FIRST_HOP, 170))
		local d, len = 0, first
		while d < distance - 0.5 do
			if len < 14 then
				table.insert(hops, { d, distance, 0 })
				break
			end
			len = math.min(len, distance - d)
			local height = #hops == 0 and math.clamp(len * 0.18, 20, 120) or math.clamp(len * 0.03, 0.5, 8)
			table.insert(hops, { d, d + len, height })
			d += len
			len *= Config.SKIP_DECAY
		end
		local water = waterAt(pointAt(distance), 5.5)
		for i, h in ipairs(hops) do
			h[4] = i == 1 and origin.Y or hops[i - 1][5]
			h[5] = waterAt(pointAt(h[2]), water) + BALL_RADIUS
		end

		-- the owner's picked cannonball from the stand (its colour and band)
		local look = Config.GetBall(owner:GetAttribute("Ball")) or Config.Balls[1]
		local ball = new("Part", {
			Name = "Cannonball", Shape = Enum.PartType.Ball, Size = Vector3.one * BALL_RADIUS * 2,
			Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
			Material = Enum.Material.SmoothPlastic, Color = look.Color, CFrame = CFrame.new(origin),
			Parent = workspace,
		})
		-- Alex's model of the ball when there is one, else a band round the plain ball
		local balls = ReplicatedStorage:FindFirstChild("CannonBalls")
		local model = balls and balls:FindFirstChild(look.Id)
		if model and model:IsA("Model") then
			model = model:Clone()
			local _, size = model:GetBoundingBox()
			model:ScaleTo(model:GetScale() * BALL_RADIUS * 2 / math.max(size.X, size.Y, size.Z))
			model:PivotTo(ball.CFrame)
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Anchored = false
					d.CanCollide, d.CanQuery, d.CanTouch, d.Massless = false, false, false, true
					new("WeldConstraint", { Part0 = ball, Part1 = d, Parent = d })
				end
			end
			model.Parent = ball
			ball.Transparency = 1
		else
			local band = new("Part", {
				Name = "Band", Shape = Enum.PartType.Cylinder, Size = Vector3.new(BALL_RADIUS * 0.35, BALL_RADIUS * 2.08, BALL_RADIUS * 2.08),
				CanCollide = false, CanQuery = false, CanTouch = false, Massless = true,
				Material = Enum.Material.SmoothPlastic, Color = look.Band, CFrame = ball.CFrame * CFrame.Angles(0, math.rad(90), 0),
				Parent = ball,
			})
			new("WeldConstraint", { Part0 = ball, Part1 = band, Parent = ball })
		end
		local a0 = new("Attachment", { Position = Vector3.new(0, 0.9, 0), Parent = ball })
		local a1 = new("Attachment", { Position = Vector3.new(0, -0.9, 0), Parent = ball })
		new("Trail", {
			Attachment0 = a0, Attachment1 = a1, Lifetime = 0.45, LightEmission = 0.4, FaceCamera = true,
			Color = ColorSequence.new(look.Band, look.Band:Lerp(look.Color, 0.5)),
			Transparency = NumberSequence.new(0.1, 1), WidthScale = NumberSequence.new(1, 0.2), Parent = ball,
		})

		local borders, nextBorder = {}, 1
		local cam = workspace.CurrentCamera
		if mine then
			endFlight()
			borders = getBorders(origin, dir)
			while borders[nextBorder] and borders[nextBorder].At <= 0 do
				nextBorder += 1
			end
			fitGui()
			counter.Text = "0 m"
			flightGui.Enabled = true
			setSideMenu(false)
			cam.CameraType = Enum.CameraType.Scriptable
			Kit.playSound("Launch")
		end
		splash(origin, true)

		local start = os.clock()
		local hopIndex, lastShown, paid = 1, -1, 0
		local camPos = nil
		local conn
		conn = RunService.Heartbeat:Connect(function(dt)
			local u = math.clamp((os.clock() - start) / duration, 0, 1)
			local dist = distance * (1 - (1 - u) ^ 2) -- fast out of the cannon, slows to a stop
			while hops[hopIndex + 1] and dist >= hops[hopIndex][2] do
				local done = hops[hopIndex]
				hopIndex += 1
				local p = pointAt(done[2])
				splash(Vector3.new(p.X, done[5] - BALL_RADIUS + 0.2, p.Z), hopIndex == 2)
				if mine then
					Kit.playSound("Skip")
					local share = math.floor(cash * done[2] / distance) - paid
					if share > 0 then
						paid += share
						cashPop(share)
					end
				end
			end
			local h = hops[hopIndex]
			local k = h[2] > h[1] and math.clamp((dist - h[1]) / (h[2] - h[1]), 0, 1) or 1
			local y = h[4] + (h[5] - h[4]) * k + 4 * h[3] * k * (1 - k)
			local p = pointAt(dist)
			p = Vector3.new(p.X, y, p.Z)
			ball.CFrame = CFrame.new(p) * CFrame.Angles(0, 0, -dist / BALL_RADIUS)

			if mine then
				-- low chase camera, eased in so the first frame isn't a jump
				local want = p - dir * 16 + Vector3.new(0, 4.5, 0)
				camPos = camPos and camPos:Lerp(want, math.min(dt * 12, 1)) or want
				if (camPos - want).Magnitude > 40 then
					camPos = want
				end
				cam.CFrame = CFrame.lookAt(camPos, p + dir * 40 + Vector3.new(0, 1, 0))

				local shown = math.floor(dist)
				if shown ~= lastShown then
					lastShown = shown
					counter.Text = commas(math.floor(shown * reported / distance)) .. " m"
					counterScale.Scale = 1 + 0.05 * math.sin(os.clock() * 22) * (1 - u)
				end
				local b = borders[nextBorder]
				if b and dist >= b.At then
					nextBorder += 1
					popBanner(b.Name, b.Color:Lerp(Color3.new(1, 1, 1), 0.35))
					Kit.playSound("Open")
				end
			end
			if u >= 1 then
				conn:Disconnect()
				if mine then
					if cash - paid > 0 then
						cashPop(cash - paid)
					end
					counterScale.Scale = 1.3
					TweenService:Create(counterScale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
				end
				local last = hops[#hops]
				local stop = pointAt(distance)
				bigSplash(Vector3.new(stop.X, last[5] - BALL_RADIUS + 0.2, stop.Z))
				if mine then
					Kit.playSound("Splash")
				end
				TweenService:Create(ball, TweenInfo.new(0.8), { Transparency = 1 }):Play()
				Debris:AddItem(ball, Config.RETURN_DELAY + 1)
			end
		end)
	end)

	-----------------------------------------------------------------------
	-- Egg stands: walk up to one and the egg menu opens on that egg
	-----------------------------------------------------------------------
	local EGG_RANGE = 11
	local nearEgg = nil
	task.spawn(function()
		local stands = workspace:WaitForChild("EggStands", 30)
		if not stands then
			return
		end
		-- eggs turn slowly on their own stands (no bob: the stand stays on the floor)
		local spinners = {}
		for _, stand in ipairs(stands:GetChildren()) do
			local egg = stand:FindFirstChild("Egg")
			if egg then
				table.insert(spinners, { Model = egg, Home = egg:GetPivot(), Phase = #spinners })
			end
		end
		RunService.Heartbeat:Connect(function()
			local t = os.clock()
			for _, e in ipairs(spinners) do
				e.Model:PivotTo(e.Home * CFrame.Angles(0, t * 0.6 + e.Phase, 0))
			end
		end)
		while true do
			task.wait(0.2)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local found, best = nil, EGG_RANGE
			if root and not player:GetAttribute("Launching") then
				for _, stand in ipairs(stands:GetChildren()) do
					local d = (stand:GetPivot().Position - root.Position) * Vector3.new(1, 0, 1)
					if stand:GetAttribute("EggId") and d.Magnitude < best then
						found, best = stand, d.Magnitude
					end
				end
			end
			if found ~= nearEgg then
				if found then
					ctx.Open("Pets", "Eggs", found:GetAttribute("EggId"))
				elseif nearEgg then
					ctx.CloseIf("Pets")
				end
				nearEgg = found
			end
		end
	end)

	-----------------------------------------------------------------------
	-- Pets follow their owners: walkers hop along the ground, flyers hover (PetFollow.lua)
	-----------------------------------------------------------------------
	require(script.Parent.PetFollow)(ctx)

	-----------------------------------------------------------------------
	-- Water: Stone Skipping style light lines drifting over the ocean
	-----------------------------------------------------------------------
	local ocean = workspace:FindFirstChild("map1b") and workspace.map1b:FindFirstChild("Ocean", true)
	if ocean and Icons.Caustics and Icons.Caustics ~= "" then
		local layers = {}
		for _, p in ipairs(ocean:GetDescendants()) do
			if p:IsA("MeshPart") then
				for i, size in ipairs({ 34, 21 }) do
					table.insert(layers, {
						Speed = i == 1 and 2.2 or -1.6,
						Texture = new("Texture", {
							Name = "Caustics" .. i,
							Texture = Icons.Caustics,
							Face = Enum.NormalId.Top,
							StudsPerTileU = size,
							StudsPerTileV = size,
							Transparency = i == 1 and 0.35 or 0.6,
							Parent = p,
						}),
					})
				end
			end
		end
		local t = 0
		RunService.Heartbeat:Connect(function(dt)
			t += dt
			for _, l in ipairs(layers) do
				l.Texture.OffsetStudsU = t * l.Speed
				l.Texture.OffsetStudsV = t * l.Speed * 0.4
			end
		end)
	end

	-----------------------------------------------------------------------
	-- Settings
	-----------------------------------------------------------------------
	local music
	if Config.Sounds and Config.Sounds.Music and Config.Sounds.Music ~= "" then
		music = new("Sound", { SoundId = Config.Sounds.Music, Looped = true, Volume = 0.3, Parent = workspace })
		music:Play()
	end

	local function applySettings()
		local s = State.Data and State.Data.Settings
		if not s then
			return
		end
		if music then
			music.Volume = s.Music and 0.3 or 0
		end
		for _, sound in pairs(Kit.Sounds) do
			sound.Volume = s.Sfx and 0.5 or 0
		end
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player and p.Character then
				for _, d in ipairs(p.Character:GetDescendants()) do
					if d:IsA("BasePart") or d:IsA("Decal") then
						d.LocalTransparencyModifier = s.ShowPlayers and 0 or 1
					end
				end
			end
		end
		Lighting.GlobalShadows = not s.LowGraphics
		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("ParticleEmitter") and d.Parent and not d.Parent:IsA("Attachment") then
				d.Enabled = not s.LowGraphics
			end
		end
	end
	-- only re-apply when a setting actually changed (the map is huge)
	local lastSettings = ""
	State.Changed:Connect(function(what)
		local s = what == nil and State.Data and State.Data.Settings
		if s then
			local key = tostring(s.Music) .. tostring(s.Sfx) .. tostring(s.ShowPlayers) .. tostring(s.ShowPets) .. tostring(s.LowGraphics)
			if key ~= lastSettings then
				lastSettings = key
				applySettings()
			end
		end
	end)
	Players.PlayerAdded:Connect(function(p)
		p.CharacterAdded:Connect(function()
			task.wait(1)
			applySettings()
		end)
	end)

	-- the cannonball stand in the lobby (its own module)
	task.spawn(require(script.Parent.BallStand), ctx)
end
