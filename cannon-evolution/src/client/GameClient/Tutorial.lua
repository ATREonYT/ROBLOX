--[[
	Tutorial  (ModuleScript)
	First-time guide:
	  1. A short cutscene at the start of the water: your cannon fires, the
	     camera chases the ball far down the map (each area's name pops up),
	     then the guide talks to you and the camera glides over the training
	     booths (Skip button). Built to the vault's "Cameras and Cutscenes"
	     rules: lock, hide, letterbox, cut on action, a wide after the big
	     moment, and restore everything exactly, even if something fails.
	  2. A quest bar at the top with a live count, e.g. TRAIN POWER (12/30).
	  3. A chain of white arrows floating straight from you to the next thing to
	     do, and a pointer on the menu button when the step is in the UI.
	  4. A TUTORIAL COMPLETE! screen after the first rebirth.
	Each step finishes on its own when you do it, and progress is saved.

	All words the player sees are in TEXT below, so they're easy to rewrite.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Everything the tutorial says.
local TEXT = {
	Speaker = "CAPTAIN BOOM",
	IntroLine0 = "Welcome to Cannon Evolution!",
	IntroLine1 = "This cannon can fire you across the whole sea!",
	IntroLine2 = "Train your Power at the booths to fly further!",
	IntroLine3 = "Then walk into the Launch Zone. Ready?",
	Skip = "Skip",
	Tag = "TUTORIAL",
	Train = "TRAIN POWER",
	Launch = "LAUNCH",
	Cash = "EARN CASH",
	Hatch = "HATCH AN EGG",
	Power = "GET REBIRTH POWER",
	RebirthCash = "GET REBIRTH CASH",
	Rebirth = "REBIRTH NOW",
	JumpHint = "JUMP TO LEAVE TRAINING",
	Complete = "TUTORIAL COMPLETE!",
	CompleteSub = "Rebirth #1",
	CompleteReward = "+50% POWER",
	Continue = "Tap to continue",
}

-- The intro, shot by shot (vault "Cameras and Cutscenes": establish, action, aftermath, return):
--   A  establish: a wide over the water looking back at your cannon and the guide
--   B  fire: close on the cannon, a little wind-up shake, then cut on the shot
--   C  chase: the ball skips far down the map; each area's name pops up as it passes
--   D  aftermath: a high wide over the last splash
--   E  back at the cannon the guide talks to you
--   F  the camera glides over the training booths and back behind you
local WATER_Y = 5.4
local ESTABLISH_TIME = 3.2
local WINDUP_TIME = 0.9
local AFTER_TIME = 1.8
local TALK_TIME = 3.6
local PADS_TIME = 5.5
local MAX_TIME = 40 -- watchdog: the intro always hands control back by then
-- the ball's run, as distance down the map from the muzzle: { seconds, studs }.
-- Short skips at the near areas, then bigger and bigger ones to show the whole map.
local CHASE = {
	{ 0, 0 },
	{ 1.2, 170 },
	{ 2.1, 430 },
	{ 3.1, 900 },
	{ 4.2, 1800 },
	{ 5.4, 3300 },
	{ 6.6, 5200 },
	{ 7.8, 7400 },
	{ 8.6, 7600 },
}
local ANIM = {
	Idle = "rbxassetid://507766388",
	Wave = "rbxassetid://507770239",
	Point = "rbxassetid://507770453",
}

-- Studio only: set to true to watch the whole tutorial again on your own save
local REPLAY_IN_STUDIO = false

local TRAIN_GOAL = 30
local LAUNCH_GOAL = 2

-- Catmull-Rom spline through points: smooth speed and direction
local function spline(points, t)
	local n = #points - 1
	local f = math.clamp(t, 0, 1) * n
	local i = math.min(math.floor(f) + 1, n)
	local u = f - (i - 1)
	local p1, p2 = points[i], points[i + 1]
	local p0 = points[i - 1] or (p1 + (p1 - p2))
	local p3 = points[i + 2] or (p2 + (p2 - p1))
	local u2, u3 = u * u, u * u * u
	return 0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u2 + (-p0 + 3 * p1 - 3 * p2 + p3) * u3)
end

local function smooth(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- Monotone cubic through { time, value } keys: never runs backwards, no
-- sudden speed changes. Returns value and which segment it's in.
local function monotone(keys)
	local n = #keys
	local d, m = {}, {}
	for i = 1, n - 1 do
		d[i] = (keys[i + 1][2] - keys[i][2]) / (keys[i + 1][1] - keys[i][1])
	end
	m[1], m[n] = d[1], d[n - 1]
	for i = 2, n - 1 do
		if d[i - 1] * d[i] <= 0 then
			m[i] = 0
		else
			local h0, h1 = keys[i][1] - keys[i - 1][1], keys[i + 1][1] - keys[i][1]
			local w1, w2 = 2 * h1 + h0, h1 + 2 * h0
			m[i] = (w1 + w2) / (w1 / d[i - 1] + w2 / d[i])
		end
	end
	return function(t)
		t = math.clamp(t, keys[1][1], keys[n][1])
		local k = 1
		while k < n - 1 and t > keys[k + 1][1] do
			k += 1
		end
		local h = keys[k + 1][1] - keys[k][1]
		local s = (t - keys[k][1]) / h
		local s2, s3 = s * s, s * s * s
		local v = (2 * s3 - 3 * s2 + 1) * keys[k][2] + (s3 - 2 * s2 + s) * h * m[k] + (-2 * s3 + 3 * s2) * keys[k + 1][2] + (s3 - s2) * h * m[k + 1]
		return v, k
	end
end

return function(ctx)
	local Kit, Config, State = ctx.Kit, ctx.Config, ctx.State
	local new = Kit.new
	local player = ctx.Player

	-----------------------------------------------------------------------
	-- Where things are
	-----------------------------------------------------------------------
	local function stationPad(id)
		local stations = workspace:FindFirstChild("TrainingStations")
		local s = stations and stations:FindFirstChild("Station_" .. id)
		return s and (s:FindFirstChild("Pad") or s.PrimaryPart)
	end
	local function bestStation(data)
		local best = Config.Stations[1]
		for _, s in ipairs(Config.Stations) do
			local open = if s.Pass then State.Passes and State.Passes[s.Pass] else data.Rebirths >= s.Rebirths
			if open and s.Gain > best.Gain then
				best = s
			end
		end
		return stationPad(best.Id)
	end
	local function launchZone()
		return workspace:FindFirstChild("LaunchZone")
	end
	local function eggStand()
		local stands = workspace:FindFirstChild("EggStands")
		local s = stands and stands:FindFirstChild("StarterEgg")
		return s and (s.PrimaryPart or s:FindFirstChildWhichIsA("BasePart", true))
	end
	local function mainGui()
		return player.PlayerGui:FindFirstChild("MainUI")
	end
	local function menuButton(name)
		local main = mainGui()
		local menu = main and main:FindFirstChild("Menu", true)
		return menu and menu:FindFirstChild(name)
	end
	local function eggBuyButton()
		local panel = ctx.Panels.Pets
		if not (panel and panel.Frame.Visible) then
			return nil
		end
		return panel.Frame:FindFirstChild("EggBuy1", true)
	end
	local function rebirthPanelButton()
		local panel = ctx.Panels.Rebirth
		if not (panel and panel.Frame.Visible) then
			return nil
		end
		return panel.Frame:FindFirstChild("RebirthButton", true)
	end

	-----------------------------------------------------------------------
	-- Steps. Count returns (have, goal); Target is a part in the world;
	-- Point is a UI button to point at instead.
	-----------------------------------------------------------------------
	local launchBase = nil
	local STEPS = {
		{
			Label = function()
				return TEXT.Train
			end,
			Count = function(data)
				return math.min(math.floor(data.Power), TRAIN_GOAL), TRAIN_GOAL
			end,
			Target = function()
				return stationPad(1)
			end,
		},
		{
			Label = function()
				return TEXT.Launch
			end,
			Count = function(data)
				launchBase = launchBase or data.TotalLaunches
				return math.min(data.TotalLaunches - launchBase, LAUNCH_GOAL), LAUNCH_GOAL
			end,
			Target = launchZone,
		},
		{
			Label = function()
				return TEXT.Cash
			end,
			Count = function(data)
				local price = Config.GetEgg("Starter").Price
				if #data.Pets > 0 then
					return price, price
				end
				return math.min(math.floor(data.Cash), price), price
			end,
			Target = launchZone,
		},
		{
			Label = function()
				return TEXT.Hatch
			end,
			Count = function(data)
				return #data.Pets > 0 and 1 or 0, 1
			end,
			Target = eggStand,
			Point = eggBuyButton,
			-- after the hatch reveal, close the egg menu so the next step is in view
			DoneDelay = 4,
			Done = function()
				ctx.CloseIf("Pets")
			end,
		},
		{
			Label = function(data)
				local power = Config.RebirthCost(data.Rebirths)
				return data.Power < power and TEXT.Power or TEXT.RebirthCash
			end,
			Count = function(data)
				if data.Rebirths > 0 then
					return 1, 1
				end
				local power, cash = Config.RebirthCost(0)
				if data.Power < power then
					return math.floor(data.Power), power
				end
				return math.min(math.floor(data.Cash), cash), cash
			end,
			Target = function(data)
				local power = Config.RebirthCost(data.Rebirths)
				return data.Power < power and bestStation(data) or launchZone()
			end,
		},
		{
			Label = function()
				return TEXT.Rebirth
			end,
			Count = function(data)
				return math.min(data.Rebirths, 1), 1
			end,
			Point = function()
				return rebirthPanelButton() or menuButton("Rebirth")
			end,
			-- clear the menu away so the TUTORIAL COMPLETE screen has the stage to itself
			Done = function()
				ctx.Close()
			end,
		},
	}

	-----------------------------------------------------------------------
	-- Screen
	-----------------------------------------------------------------------
	local gui = new("ScreenGui", { Name = "Tutorial", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 40, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Enabled = false, Parent = player.PlayerGui })
	local holder = new("Frame", { Name = "Scaled", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui })
	local uiScale = new("UIScale", { Parent = holder })
	local function fit()
		local cam = workspace.CurrentCamera
		local s = math.min(cam.ViewportSize.X / 1280, cam.ViewportSize.Y / 720)
		if s <= 0 then
			return
		end
		uiScale.Scale = s
		holder.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	fit()

	-- quest bar
	local QUEST_Y = 108
	local quest = new("Frame", { Name = "Quest", BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(470, 50), Position = UDim2.new(0.5, 0, 0, QUEST_Y), AnchorPoint = Vector2.new(0.5, 0), Visible = false, ZIndex = 2, Parent = holder })
	Kit.corner(12, quest)
	Kit.stroke(3.5, nil, quest)
	local questGrad = Kit.gradient(Kit.Colors.HeaderTop, Kit.Colors.HeaderBottom, quest)
	local gloss = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.7, Size = UDim2.new(1, -12, 0.42, 0), Position = UDim2.fromOffset(6, 4), ZIndex = 3, Parent = quest })
	Kit.corner(8, gloss)
	Kit.shine(quest, 4)
	local tag = new("Frame", { Name = "Tag", BackgroundColor3 = Kit.Colors.Outline, Size = UDim2.fromOffset(112, 22), Position = UDim2.new(0.5, 0, 0, -12), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 5, Parent = quest })
	Kit.corner(8, tag)
	Kit.text({ Text = TEXT.Tag, Size = 15, Color = Kit.Colors.Yellow, Stroke = false, ZIndex = 6, Parent = tag })
	local questText = Kit.text({ Text = "", Size = 28, Scaled = true, MaxSize = 28, StrokeSize = 3, FrameSize = UDim2.new(1, -24, 1, -10), Position = UDim2.new(0.5, 0, 0.5, 2), Anchor = Vector2.new(0.5, 0.5), ZIndex = 5, Parent = quest })
	local questScale = Kit.scale(quest)
	local jumpHint = Kit.text({ Text = TEXT.JumpHint, Size = 24, Color = Kit.Colors.Red, StrokeSize = 3, FrameSize = UDim2.new(1, 0, 0, 28), Position = UDim2.new(0.5, 0, 1, 6), Anchor = Vector2.new(0.5, 0), ZIndex = 5, Parent = quest })
	jumpHint.Visible = false

	-- pointer for UI steps: a pulsing ring around the button and a bouncing arrow under it
	local ring = new("Frame", { Name = "Ring", BackgroundTransparency = 1, Visible = false, ZIndex = 10, Parent = gui })
	Kit.corner(14, ring)
	local ringStroke = Kit.stroke(4, Kit.Colors.Yellow, ring)
	-- your Arrow icon (points right) turned to point up; falls back to an emoji until the icons are uploaded
	local pointer = Kit.icon("Arrow", { Size = UDim2.fromOffset(64, 64), Anchor = Vector2.new(0.5, 0), Rotation = -90, ZIndex = 11, Parent = gui })
	pointer.Visible = false

	-- bouncing arrow over the world target
	local marker = new("BillboardGui", { Name = "TutorialMarker", Size = UDim2.fromOffset(90, 90), AlwaysOnTop = true, LightInfluence = 0, Enabled = false, Parent = gui })
	Kit.icon("Arrow", { Size = UDim2.fromScale(1, 1), Rotation = 90, Parent = marker })

	-----------------------------------------------------------------------
	-- Arrow line, matched to Alex's Stone Skipping recording: a tight chain
	-- of white arrowheads (a dart with a notch at the back) with a thin dark
	-- outline, floating on one straight line from you to the target (not on
	-- the ground, Alex Oct 30), turned to face the camera, flowing forward.
	-----------------------------------------------------------------------
	local ARROWS, SPACING, FLOW_SPEED = 30, 1.75, 5 -- tip to notch like the reference
	local LEN, HALF, NOTCH, THICK = 1.6, 0.8, 0.55, 0.12 -- dart length, half width, notch depth, thickness
	local RIM = 1.22 -- each dart has its own dark copy behind it, this much bigger: its outline
	local HIDDEN = CFrame.new(0, -500, 0)
	local arrowFolder = new("Model", { Name = "TutorialArrows" })
	-- each dart is two triangles (tip, barb, notch), each triangle two wedges, and the same again in dark
	-- behind it; one shared Highlight outlined the whole chain as a single jagged shape
	local arrows = {}
	for i = 1, ARROWS do
		local wedges = {}
		for w = 1, 8 do
			wedges[w] = new("WedgePart", {
				Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
				Material = Enum.Material.SmoothPlastic, CFrame = HIDDEN, Parent = arrowFolder,
				Color = w <= 4 and Color3.fromRGB(246, 246, 252) or Color3.fromRGB(30, 30, 55),
			})
		end
		arrows[i] = wedges
	end

	-- a flat triangle a, b, c from two wedges, THICK deep
	local function triangle(a, b, c, w1, w2)
		local ab, ac, bc = b - a, c - a, c - b
		local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
		if abd > acd and abd > bcd then
			c, a = a, c
		elseif acd > bcd and acd > abd then
			a, b = b, a
		end
		ab, ac, bc = b - a, c - a, c - b
		local right = ac:Cross(ab).Unit
		local up = bc:Cross(right).Unit
		local back = bc.Unit
		local height = math.abs(ab:Dot(up))
		w1.Size = Vector3.new(THICK, height, math.abs(ab:Dot(back)))
		w1.CFrame = CFrame.fromMatrix((a + b) / 2, right, up, back)
		w2.Size = Vector3.new(THICK, height, math.abs(ac:Dot(back)))
		w2.CFrame = CFrame.fromMatrix((a + c) / 2, -right, up, -back)
	end

	local function hideArrows()
		for _, wedges in ipairs(arrows) do
			for _, part in ipairs(wedges) do
				part.CFrame = HIDDEN
			end
		end
	end

	-- a straight line through the air from you to the target: it points at one thing, never bends
	-- round obstacles and never follows the ground (Alex, Oct 30)
	local route = nil -- { points = {Vector3}, lengths = {cumulative}, total = n }

	local function setRoute(points)
		local lengths, total = { 0 }, 0
		for i = 2, #points do
			total += (points[i] - points[i - 1]).Magnitude
			lengths[i] = total
		end
		route = { points = points, lengths = lengths, total = total }
	end

	local function pointOnRoute(d)
		local pts, lens = route.points, route.lengths
		for i = 2, #pts do
			if d <= lens[i] then
				local seg = lens[i] - lens[i - 1]
				local u = seg > 0 and (d - lens[i - 1]) / seg or 0
				return pts[i - 1]:Lerp(pts[i], u), (pts[i] - pts[i - 1])
			end
		end
		return pts[#pts], pts[#pts] - pts[#pts - 1]
	end

	local function drawArrows(target)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		-- no line while you fly or while you're locked on a training pad (the jump hint shows instead)
		if not (root and target) or player:GetAttribute("Launching") or State.Training ~= nil then
			hideArrows()
			return
		end
		if arrowFolder.Parent ~= workspace then
			arrowFolder.Parent = workspace
		end
		local from = root.Position
		setRoute({ from, target.Position })
		local total = route.total
		if total < 7 then
			hideArrows()
			return
		end
		local camPos = workspace.CurrentCamera.CFrame.Position
		local phase = (os.clock() * FLOW_SPEED) % SPACING
		for i, wedges in ipairs(arrows) do
			local d = 2.5 + (i - 1) * SPACING + phase
			local pos, dir = pointOnRoute(d)
			dir = dir.Magnitude > 0.01 and dir.Unit or Vector3.xAxis
			local toCam = camPos - pos
			-- right under the camera an arrow fills the screen: skip it
			if d > total - 2 or toCam.Magnitude < 6 then
				for _, part in ipairs(wedges) do
					part.CFrame = HIDDEN
				end
				continue
			end
			-- flat to the screen like a sticker (as in the reference), pointing the way the line runs on screen,
			-- so the darts keep their shape even when the line runs away from you
			local normal = toCam.Unit
			local flat = dir - normal * dir:Dot(normal)
			if flat.Magnitude < 0.05 then
				flat = Vector3.yAxis - normal * normal.Y
			end
			dir = flat.Unit
			local side = dir:Cross(normal)
			-- grow in near you and shrink into the target
			local k = 0.35 + 0.65 * math.clamp(math.min((d - 2.5) / 3, (total - 2 - d) / 3), 0, 1)
			for layer = 0, 1 do
				local r = layer == 0 and k or k * RIM
				local c = pos - normal * (layer * THICK * 1.5) -- the dark copy sits just behind
				local tip = c + dir * (LEN / 2 * r)
				local tail = c - dir * (LEN / 2 * r)
				local notch = tail + dir * (NOTCH * r)
				local w = layer * 4
				triangle(tip, tail + side * (HALF * r), notch, wedges[w + 1], wedges[w + 2])
				triangle(tip, notch, tail - side * (HALF * r), wedges[w + 3], wedges[w + 4])
			end
		end
	end

	-----------------------------------------------------------------------
	-- Intro cutscene
	-----------------------------------------------------------------------
	local function loadGuide()
		local template = ReplicatedStorage:FindFirstChild("TutorialGuide")
		if not template then
			return nil
		end
		local guide = template:Clone()
		for _, d in ipairs(guide:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = d.Name == "HumanoidRootPart"
				d.CanCollide = false
				d.CanTouch = false
				d.CanQuery = false
			elseif d:IsA("Script") or d:IsA("LocalScript") then
				d:Destroy()
			end
		end
		local hum = guide:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
		guide.Parent = workspace
		local animator = hum and (hum:FindFirstChildOfClass("Animator") or new("Animator", { Parent = hum }))
		local tracks = {}
		local function play(name, looped)
			if not animator then
				return
			end
			if not tracks[name] then
				local ok, track = pcall(function()
					return animator:LoadAnimation(new("Animation", { AnimationId = ANIM[name] }))
				end)
				tracks[name] = ok and track or false
			end
			local track = tracks[name]
			if track then
				track.Looped = looped or false
				track:Play(0.25)
			end
		end
		return guide, play
	end

	local function stand(guide, pos, lookAt)
		local root = guide:FindFirstChild("HumanoidRootPart")
		local hum = guide:FindFirstChildOfClass("Humanoid")
		local height = hum and hum.HipHeight + (root and root.Size.Y / 2 or 1) or 3
		guide:PivotTo(CFrame.lookAt(Vector3.new(pos.X, pos.Y + height, pos.Z), Vector3.new(lookAt.X, pos.Y + height, lookAt.Z)))
	end

	local function splashAt(pos, big)
		local ringPart = new("Part", {
			Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
			Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = Color3.fromRGB(220, 245, 255),
			Size = Vector3.new(0.2, 2, 2), Transparency = 0.25,
			CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), Parent = workspace,
		})
		local size = big and 26 or 10
		Kit.tween(ringPart, 0.5, { Size = Vector3.new(0.2, size, size), Transparency = 1 })
		task.delay(0.6, function()
			ringPart:Destroy()
		end)
	end

	local function playIntro()
		local cam = workspace.CurrentCamera
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not (root and hum) then
			return
		end
		local StarterGui = game:GetService("StarterGui")
		local dir = Config.LAUNCH_DIRECTION.Unit
		local side = dir:Cross(Vector3.yAxis)

		-- 1. lock and hide (restored exactly in finish below)
		local main = mainGui()
		local walkSpeed, jumpPower = hum.WalkSpeed, hum.JumpPower
		local fov = cam.FieldOfView
		local coreWasOn = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.All)
		hum.WalkSpeed, hum.JumpPower = 0, 0
		if main then
			main.Enabled = false
		end
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, false)
		local guide, play = loadGuide()

		local intro = new("Frame", { Name = "Intro", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = holder })
		-- letterbox bars slide in
		local barTop = new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromScale(1, 0), ZIndex = 21, Parent = intro })
		local barBottom = new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), ZIndex = 21, Parent = intro })
		Kit.tween(barTop, 0.45, { Size = UDim2.fromScale(1, 0.11) })
		Kit.tween(barBottom, 0.45, { Size = UDim2.fromScale(1, 0.11) })
		local fade = new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 22, Parent = intro })

		-- the guide's lines: a name tag and type-on text in the bottom bar
		local speaker = Kit.text({ Text = TEXT.Speaker, Size = 22, Color = Kit.Colors.Yellow, FrameSize = UDim2.new(0.7, 0, 0, 26), Position = UDim2.new(0.5, 0, 0.89, 6), Anchor = Vector2.new(0.5, 0), ZIndex = 23, Parent = intro })
		speaker.Visible = false
		local subtitle = Kit.text({ Text = "", Size = 32, StrokeSize = 3, Wrapped = true, FrameSize = UDim2.new(0.7, 0, 0, 44), Position = UDim2.new(0.5, 0, 0.89, 32), Anchor = Vector2.new(0.5, 0), ZIndex = 23, Parent = intro })
		local sayId = 0
		local function say(line)
			sayId += 1
			local id = sayId
			speaker.Visible = line ~= nil
			subtitle.Text = line or ""
			subtitle.MaxVisibleGraphemes = 0
			task.spawn(function()
				for n = 1, #(line or "") do
					if id ~= sayId then
						return
					end
					subtitle.MaxVisibleGraphemes = n
					task.wait(0.022)
				end
				subtitle.MaxVisibleGraphemes = -1
			end)
		end

		-- big area name that pops in at the top while the ball passes
		local card = Kit.text({ Text = "", Size = 54, StrokeSize = 4, FrameSize = UDim2.new(0.8, 0, 0, 64), Position = UDim2.new(0.5, 0, 0.14, 8), Anchor = Vector2.new(0.5, 0), ZIndex = 23, Parent = intro })
		local cardScale = new("UIScale", { Scale = 1, Parent = card })
		local function showCard(name, color)
			card.Text = name
			card.TextColor3 = color or Kit.Colors.White
			card.TextTransparency = 0
			card.UIStroke.Transparency = 0
			cardScale.Scale = 1.6
			Kit.tween(cardScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
			task.delay(0.9, function()
				if card.Text == name then
					Kit.tween(card, 0.3, { TextTransparency = 1 })
					Kit.tween(card.UIStroke, 0.3, { Transparency = 1 })
				end
			end)
		end

		local skipped = false
		Kit.button({ Text = TEXT.Skip, Color = "Gray", TextSize = 24, Size = UDim2.fromOffset(110, 44), Position = UDim2.new(1, -24, 1, -20), Anchor = Vector2.new(1, 1), ZIndex = 24, Parent = intro, OnClick = function()
			skipped = true
		end })
		local diedConn = hum.Died:Connect(function()
			skipped = true
		end)
		local started = os.clock()
		local function running()
			return not skipped and os.clock() - started < MAX_TIME
		end

		local function fadeThrough(midway)
			Kit.tween(fade, 0.25, { BackgroundTransparency = 0 }, Enum.EasingStyle.Sine)
			task.wait(0.27)
			midway()
			Kit.tween(fade, 0.3, { BackgroundTransparency = 1 }, Enum.EasingStyle.Sine)
		end

		-- where things are: your cannon at the start of the water
		local spot = workspace:FindFirstChild("MyCannonSpot")
		local cannonPos = spot and spot.Position or Vector3.new(-145, 8.45, -144.25)
		local trackZ = cannonPos.Z
		local myCannon
		for _ = 1, 20 do -- it's placed when your data loads
			myCannon = workspace:FindFirstChild("MyCannon")
			if myCannon then
				break
			end
			task.wait(0.1)
		end
		local muzzle = cannonPos + dir * 7 + Vector3.new(0, 6.5, 0)
		local cannonHome
		if myCannon then
			cannonHome = myCannon:GetPivot()
			local bore = myCannon:FindFirstChild("Bore", true)
			local cf, size = myCannon:GetBoundingBox()
			cannonPos = Vector3.new(cf.X, cf.Y - size.Y / 2, cf.Z)
			muzzle = bore and bore.Position + dir * 1.5 or cf.Position + dir * size.X / 2
		end
		local facing = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
		local feet = root.Position - Vector3.new(0, hum.HipHeight + root.Size.Y / 2, 0)
		local head = root.Position + Vector3.new(0, 1.5, 0)
		local endPos = head - facing * 13 + Vector3.new(0, 3.5, 0)
		local endLook = head + facing * 20
		cam.CameraType = Enum.CameraType.Scriptable

		local function finish()
			-- 4. restore exactly: camera, FOV, HUD, Roblox menus, movement
			diedConn:Disconnect()
			if myCannon and myCannon.Parent and cannonHome then
				myCannon:PivotTo(cannonHome)
			end
			if guide and guide.Parent then
				guide:Destroy()
			end
			cam.FieldOfView = fov
			cam.CameraType = Enum.CameraType.Custom
			if hum.Parent then
				cam.CameraSubject = hum
				hum.WalkSpeed, hum.JumpPower = walkSpeed, jumpPower
			end
			if main then
				main.Enabled = true
			end
			pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, coreWasOn)
			say(nil)
			card.Text = ""
			for _, d in ipairs(intro:GetDescendants()) do
				if d:IsA("TextButton") then
					d.Visible = false
				end
			end
			Kit.tween(barTop, 0.35, { Size = UDim2.fromScale(1, 0) })
			Kit.tween(barBottom, 0.35, { Size = UDim2.fromScale(1, 0) })
			task.delay(0.4, function()
				intro:Destroy()
			end)
		end

		-- 5. survive failure: whatever happens in the shots, finish() runs
		local ok, err = pcall(function()
			-- A: establish. Out over the water, looking back at your cannon and the guide
			local guideSpot = cannonPos - dir * 2 + side * 6
			if guide then
				stand(guide, guideSpot, guideSpot + dir * 10 - side * 4)
				play("Idle", true)
				play("Wave")
			end
			say(TEXT.IntroLine0)
			local focus = cannonPos + Vector3.new(0, 4, 0)
			local t0 = os.clock()
			while running() do
				local u = smooth(math.min((os.clock() - t0) / ESTABLISH_TIME, 1))
				-- a slow crane down from high over the sea to the cannon
				local eye = focus + dir * (34 - 14 * u) + side * (16 - 6 * u) + Vector3.new(0, 18 - 12 * u, 0)
				cam.CFrame = CFrame.lookAt(eye, focus - dir * 4)
				if u >= 1 then
					break
				end
				RunService.RenderStepped:Wait()
			end

			-- B: fire. Close on the cannon, a little wind-up shake, then the shot
			if running() then
				say(nil)
				local closeEye = cannonPos - dir * 10 + side * 9 + Vector3.new(0, 7, 0)
				local t1 = os.clock()
				while running() do
					local u = (os.clock() - t1) / WINDUP_TIME
					if u >= 1 then
						break
					end
					if myCannon and cannonHome then
						local s = 0.12 * u
						myCannon:PivotTo(cannonHome + Vector3.new((math.random() - 0.5) * s, 0, (math.random() - 0.5) * s))
					end
					cam.CFrame = CFrame.lookAt(closeEye - side * u * 1.5, muzzle)
					cam.FieldOfView = fov - 8 * u
					RunService.RenderStepped:Wait()
				end
			end
			if running() and myCannon and cannonHome then
				-- recoil, then settle back
				myCannon:PivotTo(cannonHome - dir * 1.4)
				task.delay(0.25, function()
					if myCannon.Parent then
						myCannon:PivotTo(cannonHome)
					end
				end)
			end

			-- C: chase the ball far down the map
			if running() then
				local ball = new("Part", {
					Name = "IntroBall", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.8,
					Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
					Material = Enum.Material.Metal, Color = Color3.fromRGB(45, 45, 52), CFrame = CFrame.new(muzzle), Parent = workspace,
				})
				local a0 = new("Attachment", { Position = Vector3.new(0, 0.9, 0), Parent = ball })
				local a1 = new("Attachment", { Position = Vector3.new(0, -0.9, 0), Parent = ball })
				new("Trail", {
					Attachment0 = a0, Attachment1 = a1, Lifetime = 0.35, LightEmission = 0.7, FaceCamera = true,
					Color = ColorSequence.new(Color3.fromRGB(255, 230, 120), Color3.fromRGB(255, 110, 50)),
					Transparency = NumberSequence.new(0.1, 1), WidthScale = NumberSequence.new(1, 0.2), Parent = ball,
				})
				-- one muzzle flash (a single bright frame, well under the one-flash-a-second limit)
				local flash = new("Part", {
					Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
					Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 200, 90),
					Size = Vector3.one * 2, CFrame = CFrame.new(muzzle), Parent = workspace,
				})
				new("PointLight", { Color = Color3.fromRGB(255, 180, 80), Range = 20, Brightness = 5, Parent = flash })
				Kit.tween(flash, 0.3, { Size = Vector3.one * 9, Transparency = 1 })
				task.delay(0.35, function()
					flash:Destroy()
				end)
				Kit.playSound("Launch")

				-- area names along the way, from the borders on the map
				local areas = {}
				local folder = workspace:FindFirstChild("AreaBorders")
				for _, b in ipairs(folder and folder:GetChildren() or {}) do
					if b:IsA("BasePart") then
						table.insert(areas, { At = (b.Position - muzzle):Dot(dir), Name = b:GetAttribute("AreaName") or b.Name, Color = b.Color:Lerp(Color3.new(1, 1, 1), 0.35) })
					end
				end
				table.sort(areas, function(x, y)
					return x.At < y.At
				end)
				local nextArea = 1

				local dAt = monotone(CHASE)
				local endT = CHASE[#CHASE][1]
				local start = os.clock()
				local lastSeg, lastD, camPos = 1, 0, nil
				local shake = 0.6
				local p = muzzle
				while running() do
					local t = os.clock() - start
					local d, seg = dAt(t)
					-- each segment is one skip: short ones near the start, huge ones further out
					local from, to = CHASE[seg][2], CHASE[seg + 1][2]
					local u = math.clamp((d - from) / math.max(to - from, 1), 0, 1)
					local length = to - from
					local height = seg == 1 and 26 or math.clamp(length * 0.04, 4, 160)
					local y0 = seg == 1 and muzzle.Y or WATER_Y + 1.4
					local y = y0 + (WATER_Y + 1.4 - y0) * u + height * 4 * u * (1 - u)
					if seg ~= lastSeg then
						splashAt(Vector3.new(muzzle.X, WATER_Y + 0.2, trackZ) + dir * from, length > 1000)
						Kit.playSound("Skip")
						lastSeg = seg
					end
					p = Vector3.new(muzzle.X, y, trackZ) + dir * d
					ball.CFrame = CFrame.new(p) * CFrame.fromAxisAngle(side, -d / 1.4)
					while areas[nextArea] and d >= areas[nextArea].At do
						showCard(areas[nextArea].Name, areas[nextArea].Color)
						nextArea += 1
					end

					-- chase camera: behind and above, wider and higher when it's fast
					local dt = math.max(RunService.RenderStepped:Wait(), 1 / 240)
					local speed = math.abs(d - lastD) / dt
					lastD = d
					local fast = math.clamp(speed / 3000, 0, 1)
					local want = p - dir * (18 + fast * 16) + side * (6 + fast * 8) + Vector3.new(0, 6 + fast * 10, 0)
					camPos = camPos and camPos:Lerp(want, 0.3) or want
					shake = math.max(shake - dt * 2, 0) -- a short kick right after the shot
					local jolt = Vector3.new((math.random() - 0.5), (math.random() - 0.5), 0) * shake
					cam.CFrame = CFrame.lookAt(camPos + jolt, p + dir * 40 - Vector3.new(0, 2, 0))
					cam.FieldOfView = fov + fast * 22
					if t >= endT then
						break
					end
				end
				ball:Destroy()

				-- D: aftermath. A high wide over the last splash
				if running() then
					splashAt(Vector3.new(p.X, WATER_Y + 0.2, p.Z), true)
					Kit.playSound("Skip")
					local t3 = os.clock()
					local base = Vector3.new(p.X, WATER_Y, p.Z)
					while running() do
						local u = smooth(math.min((os.clock() - t3) / AFTER_TIME, 1))
						cam.FieldOfView = fov + 22 * (1 - u)
						cam.CFrame = CFrame.lookAt(base - dir * (40 + 30 * u) + side * 25 + Vector3.new(0, 30 + 25 * u, 0), base)
						if u >= 1 then
							break
						end
						RunService.RenderStepped:Wait()
					end
				end
			end
			cam.FieldOfView = fov

			-- E: back at the cannon, the guide talks to you
			local talkSpot = feet + facing * 6 + facing:Cross(Vector3.yAxis) * 1.5
			local sideF = facing:Cross(Vector3.yAxis)
			local mid = (feet + talkSpot) / 2 + Vector3.new(0, 3, 0)
			local twoShot = CFrame.lookAt(mid + sideF * 11 + Vector3.new(0, 1.5, 0) - facing * 2, mid)
			if running() then
				fadeThrough(function()
					if guide then
						stand(guide, talkSpot, feet)
						play("Point")
					end
					cam.CFrame = twoShot
				end)
				local tTalk = os.clock()
				for _, line in ipairs({ TEXT.IntroLine1, TEXT.IntroLine2 }) do
					say(line)
					local t1 = os.clock()
					while running() and os.clock() - t1 < TALK_TIME / 2 + 0.6 do
						local u = math.min((os.clock() - tTalk) / (TALK_TIME + 1.2), 1)
						cam.CFrame = twoShot * CFrame.new(-u * 3, 0, -u * 2.5) -- slow push in
						RunService.RenderStepped:Wait()
					end
				end
			end

			-- F: over the training booths and back behind you
			if running() then
				say(TEXT.IntroLine3)
				if guide then
					play("Point")
				end
				local pad = stationPad(1)
				local padPos = pad and pad.Position or (feet + facing * 30)
				-- the booths open towards the middle of the lobby, whichever side they stand on
				local open = pad and padPos.Z > -144.27 and -1 or 1
				local startCF = cam.CFrame
				local camPath = {
					startCF.Position,
					padPos + Vector3.new(14, 12, 18 * open),
					padPos + Vector3.new(-6, 9, 14 * open),
					endPos + Vector3.new(0, 4, 0) - facing * 6,
					endPos,
				}
				local lookPath = {
					mid,
					padPos,
					padPos + Vector3.new(-14, 0, 0),
					head,
					endLook,
				}
				local t2 = os.clock()
				while running() do
					local u = smooth((os.clock() - t2) / PADS_TIME)
					cam.CFrame = CFrame.lookAt(spline(camPath, u), spline(lookPath, u))
					if u >= 1 then
						break
					end
					if guide and guide.Parent and u > 0.6 then
						guide:Destroy() -- off screen by now
					end
					RunService.RenderStepped:Wait()
				end
			end
		end)
		if not ok then
			warn("[Tutorial] intro stopped early: " .. tostring(err))
		end

		-- skipping (or a failure) fades straight back to you
		if skipped or not ok or os.clock() - started >= MAX_TIME then
			fadeThrough(function()
				cam.CFrame = CFrame.lookAt(endPos, endLook)
			end)
		end
		finish()
	end

	-----------------------------------------------------------------------
	-- TUTORIAL COMPLETE!
	-----------------------------------------------------------------------
	local function playComplete()
		local shade = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 30, Parent = holder })
		Kit.tween(shade, 0.4, { BackgroundTransparency = 0.45 })
		local box = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(700, 420), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 31, Parent = shade })
		Kit.rays(box, { Size = UDim2.fromOffset(640, 640), Position = UDim2.fromScale(0.5, 0.45), Color = Kit.Colors.Yellow, Transparency = 0.55, Speed = 30, ZIndex = 31 })
		Kit.rays(box, { Size = UDim2.fromOffset(460, 460), Position = UDim2.fromScale(0.5, 0.45), Color = Color3.new(1, 1, 1), Transparency = 0.75, Speed = -18, ZIndex = 31 })
		local title = Kit.text({ Text = TEXT.Complete, Size = 76, StrokeSize = 6, FrameSize = UDim2.new(1, 0, 0, 90), Position = UDim2.fromOffset(0, 40), ZIndex = 34, Parent = box })
		new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 245, 140), Color3.fromRGB(255, 165, 20)), Rotation = 90, Parent = title })
		title.Rotation = -3
		local sub = Kit.text({ Text = TEXT.CompleteSub, Size = 34, FrameSize = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 140), ZIndex = 34, Parent = box })
		local reward = Kit.text({ Text = TEXT.CompleteReward, Size = 84, StrokeSize = 6, Color = Kit.Colors.Green, FrameSize = UDim2.new(1, 0, 0, 100), Position = UDim2.fromOffset(0, 186), ZIndex = 34, Parent = box })
		new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(170, 255, 120), Kit.Colors.GreenDark), Rotation = 90, Parent = reward })
		local tap = Kit.text({ Text = TEXT.Continue, Size = 26, FrameSize = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 312), ZIndex = 34, Parent = box })
		tap.TextTransparency = 1

		-- pop in one after another
		for i, label in ipairs({ title, sub, reward }) do
			local s = Kit.scale(label)
			s.Scale = 0
			task.delay(0.18 * i, function()
				Kit.tween(s, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
				Kit.playSound("Open")
			end)
		end
		Kit.animate(title, function(_, t)
			if t > 1 then
				Kit.scale(title).Scale = 1 + math.sin(t * 3) * 0.03
			end
		end)
		task.delay(0.9, function()
			Kit.animate(tap, function(_, t)
				tap.TextTransparency = 0.25 + math.sin(t * 4) * 0.25
			end)
		end)
		Kit.confetti(shade, 70)
		Kit.playSound("Reward")

		local closing = false
		local function close()
			if closing then
				return
			end
			closing = true
			Kit.tween(Kit.scale(box), 0.25, { Scale = 0.7 }, Enum.EasingStyle.Sine)
			Kit.tween(shade, 0.3, { BackgroundTransparency = 1 })
			for _, d in ipairs(box:GetDescendants()) do
				if d:IsA("TextLabel") then
					Kit.tween(d, 0.25, { TextTransparency = 1 })
				elseif d:IsA("ImageLabel") then
					Kit.tween(d, 0.25, { ImageTransparency = 1 })
				end
			end
			task.delay(0.3, function()
				shade:Destroy()
				ctx.Open("Rewards")
			end)
		end
		task.delay(0.9, function()
			shade.Activated:Connect(close)
		end)
	end

	-----------------------------------------------------------------------
	-- Running the steps
	-----------------------------------------------------------------------
	local step = nil -- index into STEPS, nil while finished or switching
	local lastHave = nil

	-- the bar slides down into place for a new step
	local questLow = false -- the bar drops to the bottom of the screen while a menu is open
	local function showStep()
		questLow = false
		lastHave = nil
		launchBase = nil
		route = nil
		quest.Visible = true
		quest.Position = UDim2.new(0.5, 0, 0, QUEST_Y - 40)
		questScale.Scale = 0.85
		Kit.tween(quest, 0.4, { Position = UDim2.new(0.5, 0, 0, QUEST_Y) }, Enum.EasingStyle.Back)
		Kit.tween(questScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
		Kit.playSound("Open")
	end

	local function finish()
		step = nil
		ring.Visible = false
		pointer.Visible = false
		marker.Enabled = false
		hideArrows()
		arrowFolder.Parent = nil
		Kit.tween(quest, 0.3, { Position = UDim2.new(0.5, 0, 0, QUEST_Y - 40) }, Enum.EasingStyle.Sine)
		Kit.tween(questScale, 0.3, { Scale = 0 }, Enum.EasingStyle.Sine)
	end

	local function completeStep()
		task.spawn(ctx.Request, "SetTutorial", step)
		Kit.playSound("Reward")
		questGrad.Color = ColorSequence.new(Kit.Colors.Green, Kit.Colors.GreenDark)
		Kit.pop(quest, 1.12)
		local finished = step
		local done = STEPS[finished].Done
		if done then
			task.delay(STEPS[finished].DoneDelay or 0, done)
		end
		step = nil -- pause while the bar flashes green
		ring.Visible = false
		pointer.Visible = false
		marker.Enabled = false
		hideArrows()
		task.delay(0.8, function()
			if finished >= #STEPS then
				finish()
				task.delay(0.3, function()
					questGrad.Color = ColorSequence.new(Kit.Colors.HeaderTop, Kit.Colors.HeaderBottom)
				end)
				playComplete()
				return
			end
			-- slide out, swap, slide back in
			Kit.tween(quest, 0.2, { Position = UDim2.new(0.5, 0, 0, QUEST_Y - 40) }, Enum.EasingStyle.Sine)
			Kit.tween(questScale, 0.2, { Scale = 0.85 }, Enum.EasingStyle.Sine)
			task.delay(0.2, function()
				questGrad.Color = ColorSequence.new(Kit.Colors.HeaderTop, Kit.Colors.HeaderBottom)
				step = finished + 1
				local have, goal = STEPS[step].Count(State.Data)
				questText.Text = STEPS[step].Label(State.Data) .. " (" .. Config.Format(have) .. "/" .. Config.Format(goal) .. ")"
				showStep()
			end)
		end)
	end

	local started = false
	local function start()
		local data = State.Data
		if started or not data then
			return
		end
		started = true
		local replay = REPLAY_IN_STUDIO and RunService:IsStudio()
		local saved = replay and 0 or (data.Tutorial or 0)
		if saved >= #STEPS then
			return
		end
		gui.Enabled = true
		fit()
		task.spawn(function()
			if saved == 0 and (replay or (data.TotalLaunches == 0 and data.Rebirths == 0)) then
				task.wait(1.5) -- let the world load in
				playIntro()
			end
			step = saved + 1
			local have, goal = STEPS[step].Count(State.Data)
			questText.Text = STEPS[step].Label(State.Data) .. " (" .. Config.Format(have) .. "/" .. Config.Format(goal) .. ")"
			showStep()
		end)
	end

	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		if not step then
			return
		end
		local data = State.Data
		if not data then
			return
		end
		local s = STEPS[step]

		-- where to look: a part in the world, or a button in the UI
		local target = s.Target and s.Target(data)
		drawArrows(target)
		if target then
			marker.Adornee = target
			marker.StudsOffsetWorldSpace = Vector3.new(0, 8 + math.sin(os.clock() * 4) * 1.2, 0)
			marker.Enabled = not player:GetAttribute("Launching")
		else
			marker.Enabled = false
		end
		-- still on a training pad when the step wants you somewhere else
		jumpHint.Visible = State.Training ~= nil and step > 1 and s.Target ~= nil and step ~= 5
		local button = s.Point and s.Point()
		if button and button.Parent and button.AbsoluteSize.X > 0 then
			local pad = 8
			-- AbsolutePosition is measured from the screen corner, Position from this gui's corner
			local at = button.AbsolutePosition - gui.AbsolutePosition
			ring.Position = UDim2.fromOffset(at.X - pad, at.Y - pad)
			ring.Size = UDim2.fromOffset(button.AbsoluteSize.X + pad * 2, button.AbsoluteSize.Y + pad * 2)
			ringStroke.Transparency = 0.5 - math.sin(os.clock() * 6) * 0.5
			ring.Visible = true
			pointer.Position = UDim2.fromOffset(at.X + button.AbsoluteSize.X / 2, at.Y + button.AbsoluteSize.Y + 10 + math.abs(math.sin(os.clock() * 5)) * 10)
			pointer.Visible = true
		else
			ring.Visible = false
			pointer.Visible = false
		end

		-- the count, a few times a second
		acc += dt
		if acc < 0.15 then
			return
		end
		acc = 0
		local anyOpen = false
		for _, panel in pairs(ctx.Panels) do
			if panel.Frame and panel.Frame.Visible then
				anyOpen = true
				break
			end
		end
		if anyOpen ~= questLow then
			questLow = anyOpen
			Kit.tween(quest, 0.3, { Position = anyOpen and UDim2.new(0.5, 0, 1, -78) or UDim2.new(0.5, 0, 0, QUEST_Y) }, Enum.EasingStyle.Back)
		end
		local have, goal = s.Count(data)
		questText.Text = s.Label(data) .. " (" .. Config.Format(have) .. "/" .. Config.Format(goal) .. ")"
		if lastHave and have > lastHave then
			Kit.pop(quest, 1.05)
		end
		lastHave = have
		if have >= goal then
			completeStep()
		end
	end)

	State.Changed:Connect(function(what)
		if what == nil then
			start()
		end
	end)
	start()
end
