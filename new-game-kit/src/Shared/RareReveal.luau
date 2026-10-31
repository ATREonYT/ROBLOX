--!strict
-- New Game Kit: RareReveal (the cinematic moment for a rare result; vault note 17 §2)
-- Install: ReplicatedStorage/Kit/RareReveal (ModuleScript). Client only.
--   RareReveal.Play("Legendary", {
--       target = ballOrCharacter,     -- BasePart or Model the camera looks at
--       title = "Golden Comet",        -- our own name for the result
--       odds = "1 in 2,500",           -- REQUIRED for Rare and up (kid-safe: odds always shown)
--       color = Color3.fromRGB(255, 200, 60),
--       onAnnounce = function() ... end, -- e.g. ask the server to post the server-wide line
--   }, function() print("done") end)
--   RareReveal.Plan("Mythic")  -- the beats as data: { {t=0, kind="bars", ...}, ... } (tests, previews)
--
-- The ladder (note 17 §2; our numbers, not measured from a game): every tier keeps the layers of
-- the tier below and adds one new KIND of layer, and lasts longer:
--   Common 0 s | Rare 0.6 s chime + tier-colour outline + odds card | Epic 1.2 s + zoom pulse + small shake |
--   Legendary 2 s + colour wash + 0.1 s freeze + camera push-in + burst + server line |
--   Mythic 3 s + black bars + camera orbit + sky tint + lingering aura |
--   Secret 4.5 s + sky swap + its own music sting + skip button after 1 s
-- Kid-safe: the tier colour is right from the first frame (no "almost got it" tease); no full-screen
-- flash (the burst is a local flash at the target, through Emit.TryFlash); shake through
-- Emit.MotionScale; the camera is ALWAYS handed back (also on skip, death or a second reveal);
-- the card shows the odds for every tier from Rare up.
-- Status: Plan covered by tests/RareReveal.spec.luau; Play needs a Play test in Studio.

local Emit = require(script.Parent:WaitForChild("Emit"))

local RareReveal = {}

RareReveal.Order = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

local function rgb(r: number, g: number, b: number): Color3?
	return if (Color3 :: any) then Color3.fromRGB(r, g, b) else nil
end

RareReveal.Tiers = {
	Common = { seconds = 0, color = rgb(200, 200, 200) },
	Rare = { seconds = 0.6, color = rgb(80, 170, 255) },
	Epic = { seconds = 1.2, color = rgb(180, 90, 255) },
	Legendary = { seconds = 2.0, color = rgb(255, 200, 60) },
	Mythic = { seconds = 3.0, color = rgb(255, 80, 140) },
	Secret = { seconds = 4.5, color = rgb(40, 255, 220), skipAfter = 1 },
}

-- Beats each tier ADDS (times are fractions of that tier's length so they stretch with it).
local ADDS = {
	Rare = {
		{ at = 0, kind = "chime" },
		{ at = 0, kind = "outline" }, -- tier colour from the first frame (no near-miss tease)
		{ at = 0.15, kind = "card" }, -- small card with the real odds
	},
	Epic = {
		{ at = 0, kind = "pulse", fov = 4, seconds = 0.3 }, -- the first zoom and shake of the ladder
		{ at = 0.35, kind = "shake", trauma = 0.25 },
	},
	Legendary = {
		{ at = 0, kind = "wash" },
		{ at = 0.25, kind = "freeze", seconds = 0.1 },
		{ at = 0.3, kind = "pushIn" },
		{ at = 0.3, kind = "burst" },
		{ at = 0.3, kind = "announce" },
	},
	Mythic = {
		{ at = 0, kind = "bars" },
		{ at = 0.1, kind = "orbit" },
		{ at = 0.1, kind = "skyTint" },
		{ at = 0.9, kind = "aura", seconds = 60 },
	},
	Secret = {
		{ at = 0, kind = "music" },
		{ at = 0.05, kind = "skySwap" },
		{ at = 0, kind = "skip" },
	},
}

export type Beat = { t: number, kind: string, [string]: any }

function RareReveal.Rank(tier: string): number
	for i, name in RareReveal.Order do
		if name == tier then
			return i
		end
	end
	return 1
end

-- All beats for a tier, in time order, in seconds from the start.
function RareReveal.Plan(tier: string): ({ Beat }, number)
	local rank = RareReveal.Rank(tier)
	local info = RareReveal.Tiers[RareReveal.Order[rank]]
	local length = info.seconds
	local beats: { Beat } = {}
	for i = 2, rank do
		for _, add in ADDS[RareReveal.Order[i]] or {} do
			local beat: Beat = table.clone(add) :: any
			beat.t = add.at * length
			beat.at = nil
			table.insert(beats, beat)
		end
	end
	table.sort(beats, function(a, b)
		if a.t == b.t then
			return a.kind < b.kind
		end
		return a.t < b.t
	end)
	return beats, length
end

-- Client player --------------------------------------------------------------------------------

local active: { cancel: () -> () }? = nil

local function targetPart(target: Instance?): BasePart?
	if not target then
		return nil
	end
	if target:IsA("BasePart") then
		return target
	end
	if target:IsA("Model") then
		return target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

function RareReveal.Play(tier: string, options: { [string]: any }, onDone: (() -> ())?)
	local beats, length = RareReveal.Plan(tier)
	local rank = RareReveal.Rank(tier)
	local info = RareReveal.Tiers[RareReveal.Order[rank]]
	if rank >= 2 and not options.odds then
		warn("[RareReveal] no odds given for a " .. tier .. " reveal: the card must show real odds (kid-safe rule)")
	end
	if active then
		active.cancel() -- a second reveal ends the first one cleanly
	end
	if length <= 0 then
		if onDone then
			onDone()
		end
		return
	end

	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local TweenService = game:GetService("TweenService")
	local Lighting = game:GetService("Lighting")
	local player = Players.LocalPlayer
	local camera = workspace.CurrentCamera
	local color: Color3 = options.color or info.color
	local part = targetPart(options.target)
	local cleanup: { () -> () } = {}
	local finished = false
	local savedType, savedCF, savedFov = camera.CameraType, camera.CFrame, camera.FieldOfView
	local cameraTaken = false

	local gui = Instance.new("ScreenGui")
	gui.Name = "RareReveal"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.Parent = player:WaitForChild("PlayerGui")
	table.insert(cleanup, function()
		gui:Destroy()
	end)

	local function finish()
		if finished then
			return
		end
		finished = true
		active = nil
		for i = #cleanup, 1, -1 do
			pcall(cleanup[i])
		end
		if cameraTaken then
			camera.CameraType = savedType
			camera.FieldOfView = savedFov
		end
		if onDone then
			onDone() -- only after the camera is back (CutsceneService's bug was the other order)
		end
	end
	active = { cancel = finish }

	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local c = humanoid.Died:Connect(finish)
		table.insert(cleanup, function()
			c:Disconnect()
		end)
	end

	local function tween(inst: Instance, seconds: number, props: { [string]: any }, style: Enum.EasingStyle?)
		local t = TweenService:Create(inst, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
		t:Play()
		return t
	end

	local function takeCamera()
		if not cameraTaken then
			cameraTaken = true
			savedCF = camera.CFrame
			camera.CameraType = Enum.CameraType.Scriptable
		end
	end

	local motion = Emit.MotionScale()
	local handlers: { [string]: (Beat) -> () } = {}

	handlers.pulse = function(b)
		if motion == 0 then
			return
		end
		local fov = camera.FieldOfView
		camera.FieldOfView = fov - b.fov -- zoom in a touch, then ease back
		tween(camera, b.seconds, { FieldOfView = fov }, Enum.EasingStyle.Back)
	end
	handlers.chime = function()
		if options.sound then
			options.sound:Play()
		end
	end
	handlers.card = function()
		local card = Instance.new("Frame")
		card.AnchorPoint = Vector2.new(0.5, 0.5)
		card.Position = UDim2.fromScale(0.5, 0.3)
		card.Size = UDim2.fromOffset(340, 96)
		card.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
		card.BackgroundTransparency = 0.15
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 16)
		corner.Parent = card
		local stroke = Instance.new("UIStroke")
		stroke.Color = color
		stroke.Thickness = 4
		stroke.Parent = card
		local scale = Instance.new("UIScale")
		scale.Scale = 0
		scale.Parent = card
		local function label(text: string, y: number, size: number, c: Color3)
			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.Size = UDim2.new(1, -20, 0, size + 6)
			l.Position = UDim2.fromOffset(10, y)
			l.Font = Enum.Font.FredokaOne
			l.TextSize = size
			l.TextColor3 = c
			l.Text = text
			local s = Instance.new("UIStroke")
			s.Thickness = 2
			s.Parent = l
			l.Parent = card
		end
		label(string.upper(tier), 6, 18, color)
		label(options.title or "", 28, 30, Color3.new(1, 1, 1))
		label(options.odds or "", 66, 16, Color3.fromRGB(220, 220, 220))
		card.Parent = gui
		tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		local hold = math.max(1.2, length * 0.8)
		task.delay(hold, function()
			if card.Parent then
				tween(scale, 0.2, { Scale = 0 }, Enum.EasingStyle.Quad)
			end
		end)
	end
	handlers.outline = function()
		if not options.target then
			return
		end
		local h = Instance.new("Highlight")
		h.FillColor = color
		h.FillTransparency = 0.75
		h.OutlineColor = color
		h.OutlineTransparency = 0
		h.Adornee = options.target
		h.Parent = gui
		task.delay(length, function()
			if h.Parent then
				tween(h, 0.4, { OutlineTransparency = 1, FillTransparency = 1 })
			end
		end)
	end
	handlers.shake = function(b)
		if motion == 0 then
			return
		end
		local ok, LaunchFX = pcall(require, (script.Parent :: any).LaunchFX)
		if ok then
			LaunchFX.KickCamera(b.trauma, 0, 0)
		end
	end
	handlers.wash = function()
		-- personal colour wash: under the camera, so only this player sees it (note 17 §2)
		local cc = Instance.new("ColorCorrectionEffect")
		cc.TintColor = Color3.new(1, 1, 1)
		cc.Parent = camera
		local soft = color:Lerp(Color3.new(1, 1, 1), 0.6)
		tween(cc, 0.3, { TintColor = soft, Saturation = 0.2, Contrast = 0.1 })
		table.insert(cleanup, function()
			cc:Destroy()
		end)
		task.delay(math.max(0, length - 0.4), function()
			if cc.Parent then
				tween(cc, 0.4, { TintColor = Color3.new(1, 1, 1), Saturation = 0, Contrast = 0 })
			end
		end)
	end
	handlers.freeze = function(b)
		-- a short held beat: everything waits, the camera holds still
		takeCamera()
		task.wait(b.seconds)
	end
	handlers.pushIn = function()
		if not part or motion == 0 then
			return
		end
		takeCamera()
		local look = part.Position
		local from = camera.CFrame.Position
		local to = look + (from - look).Unit * math.max(8, (from - look).Magnitude * 0.55)
		tween(camera, 0.45, { CFrame = CFrame.lookAt(to, look) }, Enum.EasingStyle.Quint)
	end
	handlers.burst = function()
		if not part then
			return
		end
		local ok, AnimeFX = pcall(require, (script.Parent :: any).AnimeFX)
		if ok then
			if Emit.TryFlash() then
				AnimeFX.Hit(part.Position, color, "Finisher")
			else
				AnimeFX.Shockwave(part.Position, color, 10)
			end
		end
	end
	handlers.announce = function()
		if options.onAnnounce then
			task.spawn(options.onAnnounce)
		end
	end
	handlers.bars = function()
		for _, top in { true, false } do
			local bar = Instance.new("Frame")
			bar.BackgroundColor3 = Color3.new(0, 0, 0)
			bar.BorderSizePixel = 0
			bar.Size = UDim2.new(1, 0, 0, 0)
			bar.AnchorPoint = Vector2.new(0, if top then 0 else 1)
			bar.Position = UDim2.fromScale(0, if top then 0 else 1)
			bar.Parent = gui
			tween(bar, 0.35, { Size = UDim2.new(1, 0, 0.1, 0) })
			task.delay(math.max(0, length - 0.35), function()
				if bar.Parent then
					tween(bar, 0.35, { Size = UDim2.new(1, 0, 0, 0) })
				end
			end)
		end
	end
	handlers.orbit = function()
		if not part or motion == 0 then
			return
		end
		takeCamera()
		local start = os.clock()
		local span = length * 0.7
		local radius = 14
		local conn = RunService.RenderStepped:Connect(function()
			local k = math.clamp((os.clock() - start) / span, 0, 1)
			local ease = 1 - (1 - k) ^ 3
			local angle = math.rad(-60 + 120 * ease)
			local look = part.Position
			local pos = look + Vector3.new(math.sin(angle) * radius, 4 + 2 * ease, math.cos(angle) * radius)
			camera.CFrame = CFrame.lookAt(pos, look)
		end)
		table.insert(cleanup, function()
			conn:Disconnect()
		end)
		task.delay(span, function()
			conn:Disconnect()
		end)
	end
	handlers.skyTint = function()
		local saved = Lighting.OutdoorAmbient
		tween(Lighting, 0.5, { OutdoorAmbient = saved:Lerp(color, 0.35) })
		table.insert(cleanup, function()
			tween(Lighting, 0.6, { OutdoorAmbient = saved })
		end)
	end
	handlers.aura = function(b)
		if part and options.aura ~= false then
			local ok, AnimeFX = pcall(require, (script.Parent :: any).AnimeFX)
			local model = if options.target and options.target:IsA("Model") then options.target else nil
			if ok and model then
				local aura = AnimeFX.Aura(model, { color = color, tier = 0.6 })
				task.delay(b.seconds, function()
					aura:Destroy()
				end)
			end
		end
	end
	handlers.music = function()
		if options.music then
			options.music:Play()
		end
	end
	handlers.skySwap = function()
		if options.sky then
			local old = Lighting:FindFirstChildOfClass("Sky")
			local new = options.sky:Clone()
			if old then
				old.Parent = nil
			end
			new.Parent = Lighting
			table.insert(cleanup, function()
				new:Destroy()
				if old then
					old.Parent = Lighting
				end
			end)
		end
	end
	handlers.skip = function()
		local button = Instance.new("TextButton")
		button.AnchorPoint = Vector2.new(1, 1)
		button.Position = UDim2.new(1, -24, 1, -24)
		button.Size = UDim2.fromOffset(110, 44)
		button.Font = Enum.Font.FredokaOne
		button.TextSize = 22
		button.Text = "Skip"
		button.TextColor3 = Color3.new(1, 1, 1)
		button.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
		button.BackgroundTransparency = 0.2
		button.Visible = false
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = button
		button.Parent = gui
		task.delay(info.skipAfter or 1, function()
			button.Visible = true
		end)
		button.Activated:Connect(finish)
	end

	task.spawn(function()
		local started = os.clock()
		for _, beat in beats do
			local wait = beat.t - (os.clock() - started)
			if wait > 0 then
				task.wait(wait)
			end
			if finished then
				return
			end
			local h = handlers[beat.kind]
			if h then
				local ok, err = pcall(h, beat)
				if not ok then
					warn("[RareReveal] " .. beat.kind .. ": " .. tostring(err))
				end
			end
		end
		local left = length - (os.clock() - started)
		if left > 0 then
			task.wait(left)
		end
		if cameraTaken and not finished then
			-- glide back to where the player's camera was, then hand it back
			tween(camera, 0.35, { CFrame = savedCF }, Enum.EasingStyle.Quad)
			task.wait(0.35)
		end
		finish()
	end)
end

function RareReveal.Cancel()
	if active then
		active.cancel()
	end
end

return RareReveal
