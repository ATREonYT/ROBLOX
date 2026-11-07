--!strict
-- +1 Chess Evolution: the client. One main action button (TRAIN / CHALLENGE / CLICK TO WIN),
-- the HUD, menus, the battle scene, badges, the guide and every client-side effect.
-- The server owns numbers; the client predicts only the meter and plays feedback.
-- Errors go to Output on [ChessUI] lines (no red box on screen).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local Kit = ReplicatedStorage:WaitForChild("Kit")
local Net = require(Kit:WaitForChild("Net"))
local Format = require(Kit:WaitForChild("Format"))
local Models = require(Kit:WaitForChild("Models"))
local Hud = require(Kit:WaitForChild("HudBuilder"))
local DuelHud = require(Kit:WaitForChild("DuelHud"))
local BadgeArt = require(Kit:WaitForChild("BadgeArt"))
local FeelKit = require(Kit:WaitForChild("FeelKit"))
local Config = require(ReplicatedStorage:WaitForChild("ChessConfig")) :: any

local function log(msg: string)
	print(`[ChessUI] {msg}`)
end
local function safe(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if not ok then
		warn(`[ChessUI] {name} failed: {err}`)
	end
end

local map = workspace:WaitForChild("Map")
local camera = workspace.CurrentCamera

---------------------------------------------------------------------------
-- HUD: reuse the saved StarterGui copy; build one only if it is missing.
---------------------------------------------------------------------------
local playerGui = player:WaitForChild("PlayerGui")
local gui = playerGui:WaitForChild("ChessHUD", 8) :: ScreenGui?
if not gui then
	gui = Hud.Build(Config)
	gui.Parent = playerGui
	log("HUD built from code (no saved ChessHUD)")
end
local G = gui :: any
G.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets

local function face(holder: Instance): any
	return holder:FindFirstChild("Face")
end
local Rail = G.Rail
local Bottom = G.Bottom
local MainHolder = G.MainButton
local MainFace = face(MainHolder)
local Panels = { Sets = G.SetsPanel, Board = G.BoardPanel, Result = G.ResultPanel, Settings = G.SettingsPanel }

---------------------------------------------------------------------------
-- State (server confirmed)
---------------------------------------------------------------------------
local S: any = {
	loaded = false, Wins = 0, Power = 0, Sets = { Wooden = true }, Equipped = "Wooden", Cleared = {},
	Settings = { Music = true, Sound = true, Reduced = false }, station = nil, lastStation = nil,
}
local listeners: { () -> () } = {}
local function onState(fn: () -> ())
	table.insert(listeners, fn)
end
local function reduced(): boolean
	return S.Settings and S.Settings.Reduced == true
end

---------------------------------------------------------------------------
-- Sound (ids live in Config.Sounds; 0 = silent slot until the owner uploads ours)
---------------------------------------------------------------------------
local soundFolder = Instance.new("Folder")
soundFolder.Name = "ChessSounds"
soundFolder.Parent = SoundService
local lastPlayed: { [string]: number } = {}
local tapLadder = { step = 0, last = 0 }
local function play(name: string, pitch: number?)
	if not S.Settings.Sound then
		return
	end
	local id = Config.Sounds[name]
	if not id or id == 0 then
		return
	end
	local now = os.clock()
	if now - (lastPlayed[name] or 0) < 0.03 then
		return
	end
	lastPlayed[name] = now
	local s = Instance.new("Sound")
	s.SoundId = `rbxassetid://{id}`
	s.Volume = 0.5
	s.PlaybackSpeed = pitch or 1
	s.Parent = soundFolder
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
end
local function tapSound()
	local now = os.clock()
	if now - tapLadder.last < 1 / 8 then
		return -- the ladder plays at most 8 a second
	end
	if now - tapLadder.last > 1 then
		tapLadder.step = 0
	end
	tapLadder.last = now
	tapLadder.step = math.min(tapLadder.step + 1, 12)
	play("Tap", 2 ^ (tapLadder.step / 12) * 0.9)
end

---------------------------------------------------------------------------
-- Motion helpers
---------------------------------------------------------------------------
local function tween(inst: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- Button compression: quick squash, springy return. Tweens a UIScale, never Size.
local function press(holder: Instance)
	local scale = holder:FindFirstChild("Press") :: UIScale?
	if not scale then
		return
	end
	tween(scale, 0.06, { Scale = 0.9 })
	task.delay(0.06, function()
		tween(scale, 0.28, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
end

local function hookButton(holder: Instance, fn: () -> ())
	local btn = face(holder) :: TextButton
	btn.Activated:Connect(function()
		press(holder)
		play("Click")
		safe(holder.Name, fn)
	end)
	btn.MouseEnter:Connect(function()
		local scale = holder:FindFirstChild("Press") :: UIScale?
		if scale then
			tween(scale, 0.3, { Scale = 1.05 }, Enum.EasingStyle.Back)
		end
	end)
	btn.MouseLeave:Connect(function()
		local scale = holder:FindFirstChild("Press") :: UIScale?
		if scale then
			tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Sine)
		end
	end)
end

-- One message line, top centre: a new message replaces the old one at once.
local msgToken = 0
local function message(textValue: string, color: Color3?)
	msgToken += 1
	local token = msgToken
	local m = G.Message :: TextLabel
	m.Text = textValue
	m.TextColor3 = color or Color3.new(1, 1, 1)
	m.TextTransparency = 0;
	(m:FindFirstChild("Outline") :: UIStroke).Transparency = 0
	m.Position = UDim2.new(0.5, 0, 0, 44)
	tween(m, 0.15, { Position = UDim2.new(0.5, 0, 0, 52) })
	task.delay(2.3, function()
		if token == msgToken then
			tween(m, 0.3, { TextTransparency = 1 })
			tween(m:FindFirstChild("Outline") :: UIStroke, 0.3, { Transparency = 1 })
		end
	end)
end

local function toast(textValue: string, color: Color3?)
	local t = G.Toast :: TextLabel
	t.Text = textValue
	t.TextColor3 = color or Color3.fromRGB(255, 220, 90)
	t.TextTransparency = 0
	local sc = t:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", t)
	sc.Scale = 0.6
	tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(1.8, function()
		if t.Text == textValue then
			tween(t, 0.3, { TextTransparency = 1 })
		end
	end)
end

-- 1v1 duel layer: VS cards, taps per second, combo, sparks, danger edges (Kit/DuelHud)
local duel = DuelHud.new(gui :: ScreenGui, { tween = tween, reduced = reduced, message = message })
-- vault feel pieces: Level chip, confetti, +N popups, HUD reveal, big moments (Kit/FeelKit)
local feel = FeelKit.new(gui :: ScreenGui, { tween = tween, reduced = reduced })
FeelKit.Default = { feel = feel, reduced = reduced } -- so FeelKit.Moment(gui, "L", text) from other scripts gets confetti

---------------------------------------------------------------------------
-- Layout: one UIScale for the whole HUD, phone placement of the main button
---------------------------------------------------------------------------
local isTouch = false
local function layout()
	local vp = camera.ViewportSize
	isTouch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	local scale = math.clamp(math.min(vp.X / 1500, vp.Y / 860), 0.5, 1.15)
	if isTouch then
		scale = math.clamp(math.min(vp.X / 1250, vp.Y / 700), 0.5, 1)
	end
	(G.Scale :: UIScale).Scale = scale
	local inv = 1 / scale
	if isTouch then
		-- Main action: fixed thumb spot above the jump button, clear of the thumbstick.
		local jumpTop = 210
		local touchGui = playerGui:FindFirstChild("TouchGui")
		local jump = touchGui and touchGui:FindFirstChild("JumpButton", true) :: GuiObject?
		if jump and jump.AbsoluteSize.Y > 0 then
			jumpTop = (vp.Y - jump.AbsolutePosition.Y) + 12
		end
		MainHolder.Position = UDim2.new(1, -18, 1, -math.floor(jumpTop * inv))
		MainHolder.Size = UDim2.fromOffset(220, 120)
		G.KeyHint.Visible = false
	else
		MainHolder.Position = UDim2.new(1, -22, 1, -22)
		MainHolder.Size = UDim2.fromOffset(236, 112)
		G.KeyHint.Visible = true
	end
	-- Panels shrink to fit narrow screens (full-screen sheet feel on phones)
	for _, p in Panels do
		local sc = p:FindFirstChild("Open") :: UIScale?
		if sc then
			sc:SetAttribute("Fit", math.min(1, (vp.X * inv - 40) / p.Size.X.Offset, (vp.Y * inv - 100) / p.Size.Y.Offset))
		end
	end
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
task.defer(layout)

---------------------------------------------------------------------------
-- Map lookups
---------------------------------------------------------------------------
local Stations = map:WaitForChild("Stations")
local Stages = map:WaitForChild("Stages")
local Displays = map:WaitForChild("SetDisplays")

local function inside(pos: Vector3, zone: BasePart, slack: number): boolean
	local p = zone.CFrame:PointToObjectSpace(pos)
	local half = zone.Size / 2
	return math.abs(p.X) <= half.X + slack and math.abs(p.Z) <= half.Z + slack and p.Y >= -half.Y - 2 and p.Y <= half.Y + 6
end

local function root(): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end
local function humanoid(): Humanoid?
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function stationOpen(id: string): (boolean, string?)
	local st = Config.Stations[id]
	if not st.built then
		return false, "Coming soon"
	end
	if st.unlock and not S.Cleared[st.unlock.stage] then
		return false, `Clear Stage {string.sub(st.unlock.stage, -1)} to unlock`
	end
	return true, nil
end
local function stageOpen(id: string): boolean
	local prev = Config.PreviousStage(id)
	return prev == nil or S.Cleared[prev] == true
end
local function nextStage(): string?
	for _, id in Config.StageOrder do
		if not S.Cleared[id] then
			return id
		end
	end
	return nil
end
local function currentStation(): string
	return S.station or S.lastStation or "PawnMill"
end

---------------------------------------------------------------------------
-- Context (what the main button does right now)
---------------------------------------------------------------------------
local ctx: any = { kind = "none" }
local battle: any = nil

local function stageNumber(id: string): number
	return Config.Stages[id].order
end

local function setMain(visible: boolean, label: string?, sub: string?, color: Color3?)
	MainHolder.Visible = visible
	if visible then
		MainFace.Label.Text = label
		MainFace.Sub.Text = sub or ""
		MainFace.BackgroundColor3 = color
	end
end

local function contextLine(t: string, color: Color3?)
	Bottom.Context.Text = t
	Bottom.Context.TextColor3 = color or Color3.fromRGB(230, 255, 220)
end

local function refreshContext()
	local r = root()
	local kind, id = "none", nil
	if battle then
		kind = "battle"
	elseif r then
		for _, m in Stations:GetChildren() do
			local deck = m:FindFirstChild("Deck") :: BasePart?
			if deck and inside(r.Position, deck, 0.5) then
				kind, id = "station", m.Name
				break
			end
		end
		if kind == "none" then
			for _, m in Stages:GetChildren() do
				if not Config.Stages[m.Name] then
					continue -- decorative future gates have no rival yet
				end
				local zone = m:FindFirstChild("Zone") :: BasePart?
				if zone and inside(r.Position, zone, 0) then
					kind, id = "stage", m.Name
					break
				end
			end
		end
	end
	ctx.kind, ctx.id = kind, id
	local keyHint = if isTouch then "" else "Press E or click"
	if kind == "battle" then
		setMain(true, "CLICK TO WIN", "Push the meter!", Hud.Colors.red)
		G.KeyHint.Text = keyHint
	elseif kind == "station" then
		local st = Config.Stations[id]
		local open, why = stationOpen(id)
		if open then
			local gain = Config.Gain(id, S.Equipped)
			setMain(true, "TRAIN", `+{gain} per tap`, Hud.Colors.green)
			contextLine(`{st.name} · +{gain} per tap`)
		else
			setMain(false)
			contextLine(`{st.name} · {why}`, Color3.fromRGB(255, 210, 90))
		end
		G.KeyHint.Text = if open then keyHint else ""
	elseif kind == "stage" then
		local st = Config.Stages[id]
		local n = stageNumber(id)
		local first = not S.Cleared[id]
		if not stageOpen(id) then
			setMain(false)
			contextLine(`Stage {n} · Clear Stage {n - 1} first`, Color3.fromRGB(255, 210, 90))
		elseif S.Power < st.power then
			setMain(false)
			contextLine(`{st.name} · Need {st.power} Power (you have {Format.Short(S.Power)})`, Color3.fromRGB(255, 210, 90))
		else
			setMain(true, "CHALLENGE", if first then `First clear +{st.reward} Wins` else "Practice (no reward)", Hud.Colors.gold)
			contextLine(`{st.name} · {st.power} Power · ` .. (if first then `+{st.reward} Wins` else "Cleared"))
		end
		G.KeyHint.Text = keyHint
	else
		setMain(false)
		contextLine("")
		G.KeyHint.Text = ""
	end
end

---------------------------------------------------------------------------
-- Power / Wins display (eased counters, coalesced "+N")
---------------------------------------------------------------------------
local shown = { power = 0, wins = 0 }
local powerValue = Instance.new("NumberValue")
local winsValue = Instance.new("NumberValue")
local powerTween: Tween? = nil
local winsTween: Tween? = nil
powerValue.Changed:Connect(function(v)
	Bottom.Power.Row.Value.Text = `{Format.Short(math.floor(v + 0.5))} Power`
end)
winsValue.Changed:Connect(function(v)
	face(Rail.Wins).Value.Text = Format.Short(math.floor(v + 0.5))
end)
local pending = { amount = 0, at = 0 }
local function popGain(amount: number)
	-- coalesce gains that land within 0.15 s into one readable pop
	local now = os.clock()
	if now - pending.at < 0.6 then
		pending.amount += amount
	else
		pending.amount = amount
	end
	pending.at = now
	local g = Bottom.Power.Gain :: TextLabel
	g.Text = `+{Format.Short(pending.amount)}`
	g.TextTransparency = 0;
	(g:FindFirstChild("Outline") :: UIStroke).Transparency = 0
	g.Position = UDim2.new(1, -110, 0.5, -16)
	tween(g, 0.5, { Position = UDim2.new(1, -110, 0.5, -36) })
	local token = now
	task.delay(0.6, function()
		if pending.at == token then
			tween(g, 0.3, { TextTransparency = 1 })
			tween(g:FindFirstChild("Outline") :: UIStroke, 0.3, { Transparency = 1 })
		end
	end)
	local bump = Bottom.Power.Bump :: UIScale
	bump.Scale = 1.15
	tween(bump, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
end

local function setCounters(first: boolean)
	if powerTween then
		powerTween:Cancel()
	end
	if winsTween then
		winsTween:Cancel()
	end
	if first then
		powerValue.Value, winsValue.Value = S.Power, S.Wins
	else
		-- retarget the running tween to the newest value (never stack)
		powerTween = tween(powerValue, 0.35, { Value = S.Power })
		winsTween = tween(winsValue, 0.5, { Value = S.Wins })
	end
	local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
	if S.Power > shown.power and not first then
		popGain(S.Power - shown.power)
		feel:Popup(head, `+{Format.Short(S.Power - shown.power)}`, "power")
	end
	if S.Wins > shown.wins and not first then
		local f = face(Rail.Wins)
		feel:Popup(head, `+{Format.Short(S.Wins - shown.wins)} Wins`, "wins")
		local sc = Rail.Wins:FindFirstChild("Press") :: UIScale
		sc.Scale = 1.15
		tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		local _ = f
	end
	shown.power, shown.wins = S.Power, S.Wins
end

-- Progress bar to the next rival
local barFill: Tween? = nil
local function refreshProgress()
	local id = nextStage()
	local bar = Bottom.Progress.Bar
	local label, frac
	if id then
		local st = Config.Stages[id]
		frac = math.clamp(S.Power / st.power, 0, 1)
		if S.Power >= st.power then
			label = `{st.name} · Ready to challenge!`
		else
			label = `{st.name} · {Format.Short(S.Power)} / {Format.Short(st.power)} Power`
		end
		face(Rail.Stage).Value.Text = `Stage {stageNumber(id)} · {st.name}`
	else
		frac = 1
		label = "All rivals beaten · more coming soon"
		face(Rail.Stage).Value.Text = "Board Run cleared!"
	end
	bar.Label.Text = label
	bar.Fill.BackgroundColor3 = if frac >= 1 then Hud.Colors.gold else Hud.Colors.green
	if barFill then
		barFill:Cancel()
	end
	barFill = tween(bar.Fill, 0.25, { Size = UDim2.fromScale(math.max(frac, 0.04), 1) })
end

---------------------------------------------------------------------------
-- Treadmills: belts, run animation, console light, tap bursts
---------------------------------------------------------------------------
local belts: { [string]: { offset: number, speed: number, target: number, model: Model, base: { [BasePart]: CFrame } } } = {}
for _, m in Stations:GetChildren() do
	local slats = m:FindFirstChild("Slats")
	local chassis = m:FindFirstChild("Chassis") :: BasePart?
	if slats and chassis then
		local base = {}
		for _, s in slats:GetChildren() do
			base[s :: BasePart] = chassis.CFrame:ToObjectSpace((s :: BasePart).CFrame)
		end
		belts[m.Name] = { offset = 0, speed = 0, target = 0, model = m :: Model, base = base }
	end
end

local trainingUntil = 0
local runTrack: AnimationTrack? = nil
local function loadRun(): AnimationTrack?
	local h = humanoid()
	local c = player.Character
	if not h or not c then
		return nil
	end
	local animate = c:FindFirstChild("Animate")
	local runFolder = animate and animate:FindFirstChild("run")
	local anim = runFolder and runFolder:FindFirstChildOfClass("Animation")
	local animator = h:FindFirstChildOfClass("Animator")
	if not anim or not animator then
		return nil
	end
	local track = animator:LoadAnimation(anim)
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = true
	return track
end
player.CharacterAdded:Connect(function()
	runTrack = nil
	trainingUntil = 0
end)

-- pooled stud bursts (small, capped)
local fxFolder = Instance.new("Folder")
fxFolder.Name = "ChessFX"
fxFolder.Parent = workspace
local burstCount = 0
local function studBurst(at: CFrame, color: Color3, n: number, shape: string?)
	if reduced() or burstCount > 40 then
		return
	end
	for i = 1, n do
		burstCount += 1
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Material = Enum.Material.Neon
		p.Color = color
		if shape == "streak" then
			p.Size = Vector3.new(0.15, 0.15, 1.6)
		elseif shape == "diamond" then
			p.Size = Vector3.new(0.45, 0.45, 0.45)
		else
			p.Size = Vector3.new(0.5, 0.35, 0.5)
			p.Material = Enum.Material.Plastic
			p.TopSurface = Enum.SurfaceType.Studs
		end
		local side = if i % 2 == 0 then 1 else -1
		local start = at * CFrame.new(side * (2.2 + math.random() * 0.6), 0.4, (math.random() - 0.5) * 6)
		p.CFrame = start
		p.Parent = fxFolder
		local up = if shape == "streak" then start * CFrame.new(0, 0.6, 4) else start * CFrame.new(side * 0.8, 2 + math.random() * 1.5, 0) * CFrame.Angles(math.random() * 3, math.random() * 3, 0)
		tween(p, 0.45, { CFrame = up, Transparency = 1, Size = p.Size * 0.4 })
		task.delay(0.46, function()
			p:Destroy()
			burstCount -= 1
		end)
	end
end

local TIER_FX = {
	PawnMill = { color = Color3.fromRGB(110, 255, 120), shape = "stud" },
	KnightSprint = { color = Color3.fromRGB(80, 230, 255), shape = "streak" },
	BishopRun = { color = Color3.fromRGB(190, 110, 255), shape = "diamond" },
	RookRig = { color = Color3.fromRGB(255, 80, 70), shape = "diamond" },
	QueenDash = { color = Color3.fromRGB(255, 220, 90), shape = "diamond" },
	KingsEndgame = { color = Color3.fromRGB(255, 200, 60), shape = "stud" },
}

local function alignOnDeck(id: string)
	local m = Stations:FindFirstChild(id)
	local align = m and m:FindFirstChild("Align") :: BasePart?
	local r = root()
	local h = humanoid()
	if not align or not r or not h then
		return
	end
	-- only snap when not already standing near the centre facing forward
	local local_ = align.CFrame:PointToObjectSpace(r.Position)
	local facing = r.CFrame.LookVector:Dot(align.CFrame.LookVector)
	if math.abs(local_.X) > 0.8 or math.abs(local_.Z) > 1.5 or facing < 0.95 then
		local height = h.HipHeight + r.Size.Y / 2
		r.CFrame = CFrame.lookAt(align.Position + Vector3.new(0, height - 0.3, 0), align.Position + Vector3.new(0, height - 0.3, 0) + align.CFrame.LookVector)
		r.AssemblyLinearVelocity = Vector3.zero
	end
end

---------------------------------------------------------------------------
-- Tapping: a local bucket mirrors the server cap, so prediction stays honest
---------------------------------------------------------------------------
local bucket = { tokens = Config.Input.tapBurst, at = os.clock() }
local function takeLocalToken(): boolean
	local now = os.clock()
	bucket.tokens = math.min(Config.Input.tapBurst, bucket.tokens + (now - bucket.at) * Config.Input.tapsPerSecond)
	bucket.at = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

local function pressMain()
	press(MainHolder)
	local fx = MainFace:FindFirstChild("ShineFx")
	local grad = fx and fx:FindFirstChild("Shine") :: UIGradient?
	if grad then
		grad.Offset = Vector2.new(-1, 0)
		tween(grad, 0.25, { Offset = Vector2.new(1, 0) })
	end
end

local challenge: (string) -> ()

local function doAction()
	refreshContext()
	if ctx.kind == "battle" and battle and not battle.ended then
		pressMain()
		duel:Tap() -- local feedback only (combo, sparks); the server still counts the taps
		if takeLocalToken() then
			battle.sent += 1
			Net.Send("Tap", "battle", battle.id)
			tapSound()
			battle.kick = (battle.kick or 0) + 1
			slap(player.Character, "Right")
			pressButton(battle, "ClockButtonA")
		end
	elseif ctx.kind == "station" then
		local id = ctx.id
		if not stationOpen(id) then
			return
		end
		pressMain()
		if takeLocalToken() then
			Net.Send("Tap", "train", id)
			if os.clock() > trainingUntil then
				alignOnDeck(id)
			end
			trainingUntil = os.clock() + 1.1
			tapSound()
			local m = Stations:FindFirstChild(id)
			local belt = m and m:FindFirstChild("Belt") :: BasePart?
			local fx = TIER_FX[id]
			-- XS event: no particles on a single tap (vault 27 C21); the +N popup and the ladder carry it
			local _ = belt and fx
		end
	elseif ctx.kind == "stage" and MainHolder.Visible then
		pressMain()
		challenge(ctx.id)
	end
end

-- the main button's own action (press() already ran in hookButton; doAction handles the rest)
face(MainHolder).Activated:Connect(function()
	safe("action", doAction)
end)
ContextActionService:BindAction("ChessMainAction", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		safe("action", doAction)
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.E, Enum.KeyCode.ButtonR2, Enum.KeyCode.ButtonX)

---------------------------------------------------------------------------
-- Gallery: floating featured pieces, padlocks, tier effects, ownership text
---------------------------------------------------------------------------
local gallery: { [string]: any } = {}
local function addLock(display: Model)
	local plinth = display:FindFirstChild("Plinth") :: BasePart
	local bb = Instance.new("BillboardGui")
	bb.Name = "Padlock"
	bb.Size = UDim2.fromScale(3, 3.4)
	bb.StudsOffset = Vector3.new(0, 10.5, 0)
	bb.Adornee = plinth
	bb.LightInfluence = 0
	bb.MaxDistance = 150
	bb.Parent = plinth
	local shackle = Instance.new("Frame")
	shackle.BackgroundTransparency = 1
	shackle.Size = UDim2.fromScale(0.62, 0.55)
	shackle.Position = UDim2.fromScale(0.19, 0)
	shackle.Parent = bb
	Instance.new("UICorner", shackle).CornerRadius = UDim.new(1, 0)
	local st = Instance.new("UIStroke")
	st.Thickness = 7
	st.Color = Color3.fromRGB(255, 196, 40)
	st.Parent = shackle
	local body = Instance.new("Frame")
	body.BackgroundColor3 = Color3.fromRGB(255, 196, 40)
	body.Size = UDim2.fromScale(1, 0.6)
	body.Position = UDim2.fromScale(0, 0.4)
	body.Parent = bb
	Instance.new("UICorner", body).CornerRadius = UDim.new(0.2, 0)
	local bs = Instance.new("UIStroke")
	bs.Thickness = 3
	bs.Color = Color3.fromRGB(28, 26, 40)
	bs.Parent = body
	local hole = Instance.new("Frame")
	hole.BackgroundColor3 = Color3.fromRGB(28, 26, 40)
	hole.Size = UDim2.fromScale(0.16, 0.36)
	hole.AnchorPoint = Vector2.new(0.5, 0.5)
	hole.Position = UDim2.fromScale(0.5, 0.5)
	hole.Parent = body
	Instance.new("UICorner", hole).CornerRadius = UDim.new(1, 0)
end

local function neonBall(parent: Instance, d: number, color: Color3, transparency: number): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(d, d, d)
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = transparency
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Parent = parent
	return p
end

local function sparkles(parent: Instance, color: Color3, rate: number, size: number)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Glints"
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, size), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(1.2, 2)
	e.Rate = rate
	e.Speed = NumberRange.new(0.5, 1.5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Parent = parent
	return e
end

for _, display in Displays:GetChildren() do
	local id = display.Name
	local set = Config.Sets[id]
	local featured = display:FindFirstChild("Featured") :: Model?
	local anchor = display:FindFirstChild("PieceAnchor") :: BasePart?
	if not set or not featured or not anchor then
		continue
	end
	local entry: any = { model = featured, base = featured:GetPivot(), phase = set.order * 0.9, fx = {} }
	if not set.available then
		addLock(display :: Model)
	end
	local core = anchor.Position + Vector3.new(0, 3.2, 0)
	local holder = Instance.new("Folder")
	holder.Name = "FX"
	holder.Parent = display
	if set.fx == "halo" then
		-- Marble: bright cyan core behind the piece, an orbit ring of three beads, small glints
		local glow = neonBall(holder, 3.6, set.accent, 0.55)
		glow.CFrame = CFrame.new(core + Vector3.new(1.2, 0, 0))
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness = set.accent, 14, 1.6
		light.Parent = glow
		entry.glow = glow
		entry.orbit = {}
		for i = 1, 3 do
			table.insert(entry.orbit, neonBall(holder, 0.55, Color3.fromRGB(200, 250, 255), 0))
		end
		sparkles(glow, Color3.fromRGB(200, 250, 255), 6, 0.6)
	elseif set.fx == "orbit" then
		entry.orbit = {}
		for i = 1, 4 do
			table.insert(entry.orbit, neonBall(holder, 0.5, set.accent, 0))
		end
		local glow = neonBall(holder, 2.6, set.accent, 0.75)
		glow.CFrame = CFrame.new(core + Vector3.new(1, 0, 0))
	elseif set.fx == "aura" then
		local glow = neonBall(holder, 3.2, set.accent, 0.7)
		glow.CFrame = CFrame.new(core + Vector3.new(1, 0, 0))
		local e = sparkles(glow, set.accent, 8, 0.9)
		e.Texture = "rbxasset://textures/particles/fire_main.dds"
		e.Speed = NumberRange.new(1, 2)
		e.Acceleration = Vector3.new(0, 2, 0)
	elseif set.fx ~= "none" then
		local glow = neonBall(holder, 2.6, set.accent, 0.7)
		glow.CFrame = CFrame.new(core + Vector3.new(1, 0, 0))
		sparkles(glow, set.accent, 3, 0.5)
	end
	entry.core = core
	gallery[id] = entry
end

local function refreshGallery()
	for id, entry in gallery do
		local set = Config.Sets[id]
		local display = Displays:FindFirstChild(id)
		local plate = display and display:FindFirstChild("Nameplate")
		local sign = plate and plate:FindFirstChild("Sign")
		local line2 = sign and sign:FindFirstChild("Line2") :: TextLabel?
		if line2 then
			if not set.available then
				line2.Text = "Coming soon"
				line2.TextColor3 = Color3.fromRGB(200, 200, 210)
			elseif S.Equipped == id then
				line2.Text = `x{set.multiplier} · EQUIPPED`
				line2.TextColor3 = Color3.fromRGB(150, 255, 140)
			elseif S.Sets[id] then
				line2.Text = `x{set.multiplier} · OWNED`
				line2.TextColor3 = Color3.fromRGB(255, 255, 255)
			else
				line2.Text = `x{set.multiplier} · {set.price} Wins`
				line2.TextColor3 = Color3.fromRGB(255, 220, 90)
			end
		end
	end
end

local function plinthPulse(id: string)
	local display = Displays:FindFirstChild(id)
	local plinth = display and display:FindFirstChild("Plinth") :: BasePart?
	if not plinth then
		return
	end
	local set = Config.Sets[id]
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, 9, 9)
	ring.CFrame = plinth.CFrame * CFrame.new(0, 0.9, 0) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Material = Enum.Material.Neon
	ring.Color = set.accent
	ring.Transparency = 0.2
	ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch = true, false, false, false
	ring.Parent = fxFolder
	tween(ring, 0.5, { Size = Vector3.new(0.3, 15, 15), Transparency = 1 })
	task.delay(0.55, function()
		ring:Destroy()
	end)
	for i = 1, 6 do
		local p = neonBall(fxFolder, 0.5, set.accent, 0)
		local a = i / 6 * math.pi * 2
		p.CFrame = plinth.CFrame * CFrame.new(math.cos(a) * 3, 1.5, math.sin(a) * 3)
		tween(p, 0.6, { CFrame = p.CFrame * CFrame.new(0, 6 + math.random() * 2, 0), Transparency = 1 })
		task.delay(0.65, function()
			p:Destroy()
		end)
	end
	play("Chime")
end

---------------------------------------------------------------------------
-- Stages: per-player gate locks, ready glow
---------------------------------------------------------------------------
local function refreshStages()
	for _, m in Stages:GetChildren() do
		if not Config.Stages[m.Name] then
			continue -- decorative future gates have no rival yet
		end
		local id = m.Name
		local gate = m:FindFirstChild("Gate")
		local barrier = gate and gate:FindFirstChild("Barrier") :: BasePart?
		local open = stageOpen(id)
		if barrier then
			barrier.CanCollide = not open
			barrier.Transparency = if open then 1 else 0.5
		end
		local glow = m:FindFirstChild("PadGlow") :: BasePart?
		if glow then
			glow:SetAttribute("Ready", open and S.Power >= Config.Stages[id].power)
		end
	end
end

---------------------------------------------------------------------------
-- Guide (first session): Train -> Challenge -> Buy -> Equip, from real state
---------------------------------------------------------------------------
local arrows: { BasePart } = {}
for i = 1, 7 do
	local a = Instance.new("WedgePart")
	a.Name = "GuideArrow"
	a.Size = Vector3.new(0.3, 1.2, 1.4)
	a.Color = Color3.new(1, 1, 1)
	a.Material = Enum.Material.Neon
	a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch, a.CastShadow = true, false, false, false, false
	a.Transparency = 1
	a.Parent = fxFolder
	arrows[i] = a
end
local guide: any = { step = 0, target = nil, customTarget = nil }
local function guideTarget(): (number, string?, Vector3?)
	if S.Power < Config.Stages.Stage1.power and not S.Cleared.Stage1 then
		local deck = Stations.PawnMill:FindFirstChild("Deck") :: BasePart
		return 1, Config.Guide[1].text, deck.Position
	elseif not S.Cleared.Stage1 then
		local zone = Stages.Stage1:FindFirstChild("Zone") :: BasePart
		return 2, Config.Guide[2].text, zone.Position
	elseif not S.Sets.Marble then
		local plinth = Displays.Marble:FindFirstChild("Plinth") :: BasePart
		return 3, if S.Wins >= Config.Sets.Marble.price then Config.Guide[3].text else "Win more to buy the Marble Set", plinth.Position
	elseif S.Equipped ~= "Marble" then
		return 4, Config.Guide[4].text, nil
	elseif Config.Guide[5] and not S.TutorialDone and (S.Promotions or 0) < 1 then
		return 5, Config.Guide[5].text, nil
	end
	return #Config.Guide + 1, nil, nil
end
local function refreshGuide()
	local step, textValue, target = guideTarget()
	guide.step, guide.target = step, target
	local holder = G.Guide
	if step > #Config.Guide or S.TutorialDone then
		holder.Visible = false
	else
		holder.Visible = true
		face(holder).Step.Text = `{step}/{#Config.Guide}`
		face(holder).Text.Text = textValue
	end
	-- spotlight the Chess Sets button on the buy/equip steps
	local sets = Rail.SetsButton
	sets:SetAttribute("Spotlight", step == 3 and S.Wins >= Config.Sets.Marble.price or step == 4)
	local loop = playerGui:FindFirstChild("ChessLoop")
	local promote = loop and loop:FindFirstChild("PromoteBtn", true)
	if promote then
		promote:SetAttribute("Spotlight", step == 5)
	end
end

---------------------------------------------------------------------------
-- HUD stages (vault 30 §2, 13 §2A): a new player sees TRAIN, the Power bar and the quest line.
-- Wins appear with the first win, Chess Sets on the buy step, Promote on the promote step,
-- everything else pops in when the tutorial completes (0.06 s apart). Returning players: all at once.
---------------------------------------------------------------------------
local hudStage = { known = false, done = false }
local function stagedParts(): { { GuiObject } }
	local loop = playerGui:FindFirstChild("ChessLoop")
	local loopRail = loop and loop:FindFirstChild("LoopRail", true)
	local function lr(name: string): GuiObject?
		return loopRail and loopRail:FindFirstChild(name) :: GuiObject?
	end
	return {
		wins = { Rail.Wins },
		sets = { Rail.SetsButton },
		promote = { lr("PromoteBtn") },
		rest = { Rail.Stage, Rail.BoardButton, Rail.SettingsButton, lr("ShopBtn"), lr("DailyBtn"), lr("GiftBtn"), lr("CodesBtn") },
	} :: any
end
local function refreshHudStage()
	local step = guide.step
	local done = S.TutorialDone == true or (S.Promotions or 0) >= 1 or step > #Config.Guide
	local show = {
		wins = done or S.Cleared.Stage1 == true or S.Wins > 0,
		sets = done or step >= 3,
		promote = done or step >= 5,
		rest = done,
	}
	local animate = hudStage.known -- the first state after joining shows everything at once
	local parts = stagedParts()
	for key, list in parts do
		local items = {}
		for _, item in list do
			if item then
				if show[key] then
					table.insert(items, item)
				else
					item.Visible = false
				end
			end
		end
		feel:Reveal(items, animate)
	end
	if done and not hudStage.done and animate then
		message("TUTORIAL COMPLETE! Everything is unlocked", Color3.fromRGB(255, 220, 90))
		play("Chime")
	end
	hudStage.known, hudStage.done = true, done
end

---------------------------------------------------------------------------
-- Panels
---------------------------------------------------------------------------
local openPanel: string? = nil
local function closePanels()
	for name, p in Panels do
		if p.Visible then
			local sc = p:FindFirstChild("Open") :: UIScale
			tween(sc, 0.12, { Scale = (sc:GetAttribute("Fit") or 1) * 0.9 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(0.12, function()
				if openPanel ~= name then
					p.Visible = false
				end
			end)
		end
	end
	openPanel = nil
	G.Dim.Visible = false
end
local function showPanel(name: string)
	if openPanel == name then
		return
	end
	closePanels()
	openPanel = name
	local p = Panels[name]
	local sc = p:FindFirstChild("Open") :: UIScale
	local fit = sc:GetAttribute("Fit") or 1
	sc.Scale = fit * 0.85
	p.Visible = true
	G.Dim.Visible = true
	tween(sc, 0.2, { Scale = fit }, Enum.EasingStyle.Back)
	play("Click")
end
for name, p in Panels do
	hookButton(face(p).Close, function()
		closePanels()
	end)
end

-- Chess Sets ------------------------------------------------------------------
local setsFace = face(Panels.Sets)
local selectedSet = "Marble"
local cards: { [string]: any } = {}
local busy = false

local function setPreviewModel(vf: ViewportFrame, kind: string, color: Color3, trim: Color3, material: Enum.Material?)
	local old = vf:FindFirstChild("Icon")
	if old then
		old:Destroy()
	end
	local m = Instance.new("Model")
	m.Name = "Icon"
	local p = Models.Piece(kind, color, 1, CFrame.Angles(0, math.rad(200), 0), { trim = trim, material = material })
	for _, part in p:GetChildren() do
		part.Parent = m
	end
	m.Parent = vf
end
local function setMaterial(id: string): Enum.Material
	return if id == "Marble" then Enum.Material.Marble elseif id == "Wooden" then Enum.Material.Wood elseif id == "Gold" or id == "Royal" then Enum.Material.Metal else Enum.Material.SmoothPlastic
end

local function refreshSets()
	local fit = setsFace
	for _, id in Config.SetOrder do
		local set = Config.Sets[id]
		local card = cards[id]
		if not card then
			card = setsFace.CardTemplate:Clone()
			card.Name = id
			card.Visible = true
			card.LayoutOrder = set.order
			card.Parent = setsFace.Grid
			local f = face(card)
			local vf = Instance.new("ViewportFrame")
			vf.Name = "Viewport"
			vf.BackgroundTransparency = 1
			vf.Size = UDim2.new(1, 0, 1, -48)
			vf.ZIndex = 35
			vf.Ambient = Color3.fromRGB(190, 190, 200)
			vf.LightDirection = Vector3.new(-1, -2, -1.5)
			local cam = Instance.new("Camera")
			cam.FieldOfView = 30
			cam.CFrame = CFrame.lookAt(Vector3.new(0, 4.6, -14), Vector3.new(0, 3.1, 0))
			cam.Parent = vf
			vf.CurrentCamera = cam
			vf.Parent = f
			setPreviewModel(vf, if set.order > 4 then "Queen" else "Knight", set.color, set.accent, setMaterial(id))
			f.Activated:Connect(function()
				press(card)
				selectedSet = id
				refreshSets()
			end)
			cards[id] = card
		end
		local f = face(card)
		f.BackgroundColor3 = if set.available then set.accent:Lerp(Color3.fromRGB(40, 44, 70), 0.35) else Color3.fromRGB(60, 62, 76)
		f.NameText.Text = string.gsub(set.name, " Set", "")
		f.Mult.Text = `x{set.multiplier}`
		f.Lock.Visible = not set.available
		local state
		if not set.available then
			state = "Soon"
		elseif S.Equipped == id then
			state = "EQUIPPED"
		elseif S.Sets[id] then
			state = "OWNED"
		else
			state = `{set.price} Wins`
		end
		f.State.Text = state
		local st = f:FindFirstChildOfClass("UIStroke") :: UIStroke
		st.Color = if selectedSet == id then Color3.new(1, 1, 1) else Color3.fromRGB(28, 26, 40)
		st.Thickness = if selectedSet == id then 5 else 3
	end
	-- preview
	local set = Config.Sets[selectedSet]
	local pv = setsFace.Preview
	setPreviewModel(pv.Viewport, if set.order > 4 then "Queen" else "Knight", set.color, set.accent, setMaterial(selectedSet))
	pv.NameText.Text = set.name
	pv.Mult.Text = `x{set.multiplier} Power per tap`
	local stationId = currentStation()
	local st = Config.Stations[stationId]
	pv.Change.Text = `{st.name}: +{Config.Gain(stationId, S.Equipped)} → +{Config.Gain(stationId, selectedSet)} per tap`
	local action = face(pv.Action)
	if not set.available then
		action.Label.Text = "Coming soon"
		action.BackgroundColor3 = Hud.Colors.grey
	elseif S.Equipped == selectedSet then
		action.Label.Text = "Equipped"
		action.BackgroundColor3 = Hud.Colors.grey
	elseif S.Sets[selectedSet] then
		action.Label.Text = "Equip"
		action.BackgroundColor3 = Hud.Colors.cyan
	elseif S.Wins >= set.price then
		action.Label.Text = `Buy · {set.price} Wins`
		action.BackgroundColor3 = Hud.Colors.green
	else
		action.Label.Text = `Need {set.price} Wins`
		action.BackgroundColor3 = Hud.Colors.grey
	end
	local _ = fit
end

hookButton(setsFace.Preview.Action, function()
	if busy then
		return
	end
	local id = selectedSet
	local set = Config.Sets[id]
	if not set.available then
		message("Coming soon!")
		return
	end
	if S.Equipped == id then
		return
	end
	busy = true
	if S.Sets[id] then
		local before = Config.Gain(currentStation(), S.Equipped)
		local r = Net.Request("Equip", id)
		busy = false
		if r.ok then
			local after = Config.Gain(currentStation(), id)
			toast(`{Config.Stations[currentStation()].name}: +{before} → +{after} per tap!`, Color3.fromRGB(150, 255, 140))
			play("Chime")
			log(`equipped {id}`)
		else
			message("Could not equip. Try again.")
		end
	elseif S.Wins >= set.price then
		local r = Net.Request("Buy", id)
		busy = false
		if r.ok then
			plinthPulse(id)
			toast(`{set.name} unlocked!`, Hud.Colors.cyan)
			log(`bought {id}`)
		else
			message(if r.code == "NeedWins" then `Need {set.price} Wins` else "Could not buy. Try again.")
		end
	else
		busy = false
		message(`Need {set.price} Wins. Beat rivals to earn Wins!`)
	end
end)

-- Board Run ---------------------------------------------------------------------
local boardFace = face(Panels.Board)
local rows: { [string]: any } = {}
local function refreshBoard()
	for i, id in Config.StageOrder do
		local st = Config.Stages[id]
		local row = rows[id]
		if not row then
			row = boardFace.RowTemplate:Clone()
			row.Name = id
			row.Visible = true
			row.LayoutOrder = i
			row.Parent = boardFace.List
			local f = face(row)
			setPreviewModel(f.Rival, st.rival, Models.CHARCOAL, st.color)
			rows[id] = row
		end
		local f = face(row)
		f.Number.Text = tostring(i)
		f.NameText.Text = st.name
		f.Info.Text = `{st.power} Power · +{st.reward} Wins first clear`
		f.Unlock.Text = if st.unlocks then `Unlocks {Config.Stations[st.unlocks].name}` else ""
		local status = face(f.Status)
		if S.Cleared[id] then
			status.Label.Text = "CLEARED"
			status.BackgroundColor3 = Hud.Colors.green
		elseif not stageOpen(id) then
			status.Label.Text = "LOCKED"
			status.BackgroundColor3 = Hud.Colors.grey
		elseif S.Power >= st.power then
			status.Label.Text = "READY"
			status.BackgroundColor3 = Hud.Colors.gold
		else
			status.Label.Text = `NEED {st.power}`
			status.BackgroundColor3 = Hud.Colors.orange
		end
	end
end

-- Settings ------------------------------------------------------------------------
local settingsFace = face(Panels.Settings)
local function refreshSettings()
	for _, key in { "Music", "Sound", "Reduced" } do
		local row = settingsFace:FindFirstChild(key)
		local t = row and face(row.Toggle)
		if t then
			local on = S.Settings[key] == true
			t.Label.Text = if on then "ON" else "OFF"
			t.BackgroundColor3 = if on then Hud.Colors.green else Hud.Colors.grey
		end
	end
end
for _, key in { "Music", "Sound", "Reduced" } do
	local row = settingsFace:FindFirstChild(key)
	if row then
		hookButton(row.Toggle, function()
			local value = not (S.Settings[key] == true)
			S.Settings[key] = value -- shown at once; the server confirms and saves
			refreshSettings()
			Net.Request("Setting", key, value)
		end)
	end
end

-- Rail buttons ---------------------------------------------------------------------
hookButton(Rail.SetsButton, function()
	selectedSet = if guide.step >= 3 and guide.step <= 4 then "Marble" else selectedSet
	refreshSets()
	showPanel("Sets")
end)
hookButton(Rail.BoardButton, function()
	refreshBoard()
	showPanel("Board")
	-- focus the next relevant stage
	local id = nextStage()
	if id and rows[id] then
		boardFace.List.CanvasPosition = Vector2.new(0, math.max(0, (Config.Stages[id].order - 1) * 110 - 40))
	end
end)
hookButton(Rail.SettingsButton, function()
	refreshSettings()
	showPanel("Settings")
end)

---------------------------------------------------------------------------
-- Battle scene
---------------------------------------------------------------------------
local meterUI = Bottom.Meter
local mBar = meterUI.Bar
local camSaved: any = nil

local function setBattleHud(on: boolean)
	meterUI.Visible = on
	Bottom.Progress.Visible = not on
	Bottom.Power.Visible = not on
	Rail.Visible = not on or not isTouch
end

local function tileAt(stageModel: Instance, pos: Vector3): BasePart?
	local best, bestD = nil, math.huge
	for _, t in (stageModel:FindFirstChild("Tiles") :: Instance):GetChildren() do
		local d = ((t :: BasePart).Position - pos).Magnitude
		if d < bestD then
			best, bestD = t :: BasePart, d
		end
	end
	return best
end

-- Badges: one prominent badge at a time; lower priority requests are dropped, never queued.
local badgeState = { key = nil :: string?, prio = 0, untilT = 0, token = 0 }
local worldBadge: BillboardGui? = nil
local function showBadge(key: string)
	local look = Config.BadgeLook[key]
	if not look then
		return
	end
	local cfg = Config.Badges
	local prio = cfg.priority[key] or 0
	local now = os.clock()
	if badgeState.key and now < badgeState.untilT and prio < badgeState.prio then
		return -- a more important badge is showing: discard this one
	end
	badgeState.token += 1
	local token = badgeState.token
	badgeState.key, badgeState.prio = key, prio
	local hold = cfg.hold[key] or cfg.hold.default
	badgeState.untilT = now + hold
	local b = Bottom.Badge
	b.Visible = true
	BadgeArt.Paint(b.Disc, key, look)
	b.Label.Text = look.label
	b.Label.TextColor3 = look.color:Lerp(Color3.new(1, 1, 1), 0.35)
	local pop = b.Pop :: UIScale
	pop.Scale = 0.5
	tween(pop, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
	-- world badge beside the player's piece
	if worldBadge then
		worldBadge.Enabled = true;
		BadgeArt.Paint((worldBadge :: any).Disc, key, look)
		local sc = (worldBadge :: any).Disc:FindFirstChildOfClass("UIScale") :: UIScale
		sc.Scale = 0.4
		tween(sc, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	if key == "Inaccuracy" or key == "Mistake" or key == "Blunder" then
		play("Warn", if key == "Blunder" then 0.8 elseif key == "Mistake" then 0.9 else 1)
		if key ~= "Inaccuracy" then
			-- short rival-side meter pulse
			local st = mBar:FindFirstChildOfClass("UIStroke") :: UIStroke
			st.Color = Color3.fromRGB(255, 60, 60)
			tween(st, 0.4, { Color = Color3.fromRGB(28, 26, 40) })
		end
	elseif key == "Great" and not reduced() then
		local sweep = Instance.new("Frame")
		sweep.BackgroundColor3 = Color3.fromRGB(70, 130, 255)
		sweep.BackgroundTransparency = 0.3
		sweep.Size = UDim2.new(0.18, 0, 1, 0)
		sweep.Position = UDim2.fromScale(-0.2, 0)
		sweep.ZIndex = 6
		sweep.Parent = mBar
		tween(sweep, 0.35, { Position = UDim2.fromScale(1, 0), BackgroundTransparency = 0.8 })
		task.delay(0.4, function()
			sweep:Destroy()
		end)
	end
	task.delay(hold, function()
		if badgeState.token == token then
			tween(pop, 0.15, { Scale = 0 })
			task.delay(0.16, function()
				if badgeState.token == token then
					b.Visible = false
					badgeState.key = nil
					if worldBadge then
						worldBadge.Enabled = false
					end
				end
			end)
		end
	end)
end

local function makeWorldBadge(adornee: BasePart): BillboardGui
	local bb = Instance.new("BillboardGui")
	bb.Name = "BadgeWorld"
	bb.Size = UDim2.fromScale(3.4, 3.4)
	bb.StudsOffset = Vector3.new(-3.4, 5.5, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Enabled = false
	bb.Adornee = adornee
	local disc = Instance.new("Frame")
	disc.Name = "Disc"
	disc.Size = UDim2.fromScale(1, 1)
	disc.BackgroundColor3 = Color3.fromRGB(250, 205, 50)
	disc.Parent = bb
	Instance.new("UICorner", disc).CornerRadius = UDim.new(1, 0)
	local st = Instance.new("UIStroke")
	st.Thickness = 4
	st.Color = Color3.fromRGB(28, 26, 40)
	st.Parent = disc
	Instance.new("UIScale", disc)
	local g = Hud.Text(disc, "Glyph", { Text = "?!", TextScaled = true, Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1) })
	local _ = g
	bb.Parent = fxFolder
	return bb
end

-- Rival automatic moves: pawn steps diagonally, knight hops an L, rook slides straight.
local function rivalMove(b: any)
	if not b.rival or b.ended then
		return
	end
	local kind = Config.Stages[b.stage].rival
	local from = b.rival:GetPivot()
	local spot = b.rivalHome
	b.moveIndex = (b.moveIndex or 0) + 1
	local k = b.moveIndex
	local offset
	if kind == "Pawn" then
		offset = Vector3.new(if k % 2 == 1 then -4 else 0, 0, 0) + Vector3.new(0, 0, if k % 2 == 1 then 4 else 0)
	elseif kind == "Knight" then
		local hops = { Vector3.new(-4, 0, 8), Vector3.new(0, 0, 0), Vector3.new(-8, 0, 4), Vector3.new(0, 0, 0) }
		offset = hops[((k - 1) % #hops) + 1]
	else
		offset = Vector3.new(if k % 2 == 1 then -8 else 0, 0, 0)
	end
	local unit = (b.tile or 4) / 4 -- offsets below are in 4-stud tiles
	offset *= unit
	if kind == "Bishop" or kind == "Queen" or kind == "King" then
		local diag = { Vector3.new(-4, 0, 4), Vector3.new(0, 0, 0), Vector3.new(4, 0, 4), Vector3.new(0, 0, 0) }
		offset = diag[((k - 1) % #diag) + 1] * unit
	end
	local target = CFrame.new(spot.Position + offset) * (spot - spot.Position)
	local start = os.clock()
	local dur = if kind == "Rook" then 0.45 else 0.35
	local height = (if kind == "Knight" then 3 elseif kind == "Pawn" or kind == "Bishop" then 1.2 else 0.6) * (b.tile or 4) / 4
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local a = math.clamp((os.clock() - start) / dur, 0, 1)
		local e = 1 - (1 - a) ^ 3
		local p = from.Position:Lerp(target.Position, e) + Vector3.new(0, math.sin(a * math.pi) * height, 0)
		if b.rival and b.rival.Parent then
			b.rival:PivotTo(CFrame.new(p) * (from - from.Position))
		end
		if a >= 1 then
			conn:Disconnect()
		end
	end)
end

-- Rival animations (assets/RivalAnims.rbxm). Live game: Config.AnimIds after Alex publishes them.
-- In Studio the KeyframeSequences are registered on the fly (temporary ids, Studio only).
local animCache: { [string]: string } = {}
local function animId(name: string): string?
	if animCache[name] then
		return animCache[name]
	end
	local ids = Config.AnimIds or {}
	if ids[name] and ids[name] ~= 0 then
		animCache[name] = `rbxassetid://{ids[name]}`
		return animCache[name]
	end
	if RunService:IsStudio() then
		local assets = ReplicatedStorage:FindFirstChild("ChessAssets")
		local ks = assets and assets:FindFirstChild("RivalAnims") and assets.RivalAnims:FindFirstChild(name)
		if ks then
			local ok, id = pcall(function()
				return game:GetService("KeyframeSequenceProvider"):RegisterKeyframeSequence(ks)
			end)
			if ok then
				animCache[name] = id
				return id
			end
			warn(`[ChessUI] could not register animation {name}: {id}`)
		end
	end
	return nil
end
local rigTracks: { [Model]: { [string]: AnimationTrack } } = {}
local function playAnim(rig: Model?, name: string, speed: number?): AnimationTrack?
	if not rig then
		return nil
	end
	local hum = rig:FindFirstChildOfClass("Humanoid")
	local animator = hum and (hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum))
	local id = animId(name)
	if not animator or not id then
		return nil
	end
	rigTracks[rig] = rigTracks[rig] or {}
	local tracks = rigTracks[rig]
	if not tracks[name] then
		local a = Instance.new("Animation")
		a.AnimationId = id
		local ok, track = pcall(function()
			return (animator :: Animator):LoadAnimation(a)
		end)
		if not ok then
			return nil
		end
		tracks[name] = track
	end
	for other, t in tracks do
		if other ~= name and t.IsPlaying and other ~= "Idle" then
			t:Stop(0.15)
		end
	end
	local track = tracks[name]
	if not track.IsPlaying then
		track:Play(0.15)
	end
	track:AdjustSpeed(speed or 1)
	return track
end
local function stopAnim(rig: Model?, name: string)
	local t = rig and rigTracks[rig] and rigTracks[rig][name]
	if t and t.IsPlaying then
		t:Stop(0.2)
	end
end
-- every rival idles at its table
task.defer(function()
	for _, m in Stages:GetChildren() do
		if not Config.Stages[m.Name] then
			continue -- decorative future gates have no rival yet
		end
		local npc = m:WaitForChild("RivalNPC", 10)
		if npc then
			playAnim(npc :: Model, "Idle")
		end
	end
end)

-- 3D duel at the table: both people slap their side of the chess clock.
-- Arms move through the shoulder joint's C0, so the avatar's own animations keep playing.
type Arm = { motor: Motor6D, base: CFrame, kick: number, hold: number }
local arms: { [Model]: { [string]: Arm } } = {}
local function armOf(rig: Model?, side: string): Arm?
	if not rig then
		return nil
	end
	arms[rig] = arms[rig] or {}
	local cache = arms[rig]
	if cache[side] and cache[side].motor.Parent then
		return cache[side]
	end
	local upper = rig:FindFirstChild(side .. "UpperArm")
	local motor = upper and upper:FindFirstChild(side .. "Shoulder")
	if not (motor and motor:IsA("Motor6D")) then
		local torso = rig:FindFirstChild("Torso") -- R6 avatars
		motor = torso and torso:FindFirstChild(side .. " Shoulder")
	end
	if not (motor and motor:IsA("Motor6D")) then
		return nil
	end
	local a = { motor = motor, base = motor.C0, kick = 0, hold = 0 }
	cache[side] = a
	return a
end
local function pressButton(b: any, name: string)
	local tbl = b.model and b.model:FindFirstChild("DuelTable")
	local btn = tbl and tbl:FindFirstChild(name) :: BasePart?
	if btn then
		btn:SetAttribute("Press", os.clock())
	end
end
local function slap(rig: Model?, side: string)
	local a = armOf(rig, side)
	if a then
		a.kick = 1
	end
end
local function setHold(rig: Model?, side: string, hold: number)
	local a = armOf(rig, side)
	if a then
		a.hold = hold
	end
end
local function releaseArms(rig: Model?)
	if rig and arms[rig] then
		for _, a in arms[rig] do
			if a.motor.Parent then
				a.motor.C0 = a.base
			end
		end
		arms[rig] = nil
	end
end
local function stepArms(dt: number)
	for rig, sides in arms do
		if not rig.Parent then
			arms[rig] = nil
			continue
		end
		for side, a in sides do
			a.kick = math.max(0, a.kick - dt * 9)
			-- up-and-slam: the arm lifts high early in the kick, then slams to the hold angle
			local lift = math.sin(a.kick * math.pi) * 0.9
			local angle = a.hold + lift
			local roll = if side == "Right" then -0.25 else 0.25
			a.motor.C0 = a.base * CFrame.Angles(angle, 0, if angle > 0 then roll * math.min(1, angle) else 0)
		end
	end
	-- clock buttons dip when slapped
	for _, m in Stages:GetChildren() do
		local tbl = m:FindFirstChild("DuelTable")
		if tbl then
			for _, name in { "ClockButtonA", "ClockButtonB" } do
				local btn = tbl:FindFirstChild(name) :: BasePart?
				local at = btn and btn:GetAttribute("Press")
				if btn and at then
					local home = btn:GetAttribute("Home") or btn.Position.Y
					btn:SetAttribute("Home", home)
					local k = math.clamp((os.clock() - at) / 0.12, 0, 1)
					btn.Position = Vector3.new(btn.Position.X, home - 0.18 * (1 - k), btn.Position.Z)
				end
			end
		end
	end
end

local function endBattleScene(b: any)
	if b.rival and b.rivalHome then
		b.rival:PivotTo(b.rivalHome)
		for _, p in b.rival:GetDescendants() do
			if p:IsA("BasePart") then
				p.Transparency = 0
			end
		end
	end
	if b.piece then
		b.piece:Destroy()
	end
	local npc = b.npc
	local me = player.Character
	setHold(me, "Right", 0)
	setHold(npc, "Left", 0)
	task.delay(if b.outcome then 1.6 else 0, function()
		releaseArms(me)
		releaseArms(npc)
	end)
	if npc and b.npcTap then
		b.npcTap = nil
		stopAnim(npc, "Tap")
		if b.outcome == "lose" then
			playAnim(npc, "Victory")
		elseif b.outcome == "win" then
			playAnim(npc, "Defeat")
		end
		task.delay(1.8, function()
			stopAnim(npc, "Victory")
			stopAnim(npc, "Defeat")
		end)
	elseif npc and b.outcome == "lose" then
		-- the rival celebrates: both arms up
		setHold(npc, "Left", 2.6)
		setHold(npc, "Right", 2.6)
		slap(npc, "Right")
	elseif npc and b.outcome == "win" then
		setHold(npc, "Left", -0.2)
		setHold(npc, "Right", -0.2)
		setHold(me, "Right", 2.6)
		setHold(me, "Left", 2.6)
	end
	if worldBadge then
		worldBadge:Destroy()
		worldBadge = nil
	end
	if camSaved then
		camera.CameraType = Enum.CameraType.Custom
		camSaved = nil
	end
	setBattleHud(false)
	meterUI.Hint.Visible = false
	safe("duel stop", function()
		duel:Stop()
	end)
end

local function startBattleScene(b: any)
	local stageModel = Stages:FindFirstChild(b.stage)
	if not stageModel then
		return
	end
	b.model = stageModel
	b.rival = stageModel:FindFirstChild("Rival")
	b.rivalHome = b.rival and b.rival:GetPivot()
	local pieceSpot = stageModel:FindFirstChild("PlayerPieceSpot") :: BasePart
	local set = Config.Sets[S.Equipped] or Config.Sets.Wooden
	b.tile = stageModel:GetAttribute("TileSize") or 4
	b.npc = stageModel:FindFirstChild("RivalNPC")
	b.piece = Models.Piece("Knight", set.color, b.tile * 0.24, pieceSpot.CFrame * CFrame.new(0, -0.04, 0), { trim = set.accent, material = setMaterial(S.Equipped) })
	b.piece.Name = "YourPiece"
	if stageModel:GetAttribute("NoBoard") then
		-- reference layout (Nov 7): no board on the mat. The piece is only the badge anchor,
		-- hidden above the player's head on the standing plate.
		local plate = stageModel:FindFirstChild("PlayerSpot") :: BasePart
		b.piece:PivotTo(plate.CFrame * CFrame.new(0, 4.5, 0))
		for _, part in b.piece:GetDescendants() do
			if part:IsA("BasePart") then
				part.Transparency = 1
			end
		end
	end
	b.piece.Parent = fxFolder
	worldBadge = makeWorldBadge(b.piece.PrimaryPart)
	-- camera: side-on at the clock end of the table, both players in profile (you on the left)
	local tbl = stageModel:FindFirstChild("DuelTable")
	local top = tbl and tbl:FindFirstChild("TableTop") :: BasePart?
	local spot = stageModel:FindFirstChild("PlayerSpot") :: BasePart
	local rivalPlate = stageModel:FindFirstChild("RivalPlate") :: BasePart?
	local centre = if top then top.Position
		elseif rivalPlate then (spot.Position + rivalPlate.Position) / 2 + Vector3.new(0, 2.5, 0)
		else spot.Position + Vector3.new(0, 3, -4.4)
	camSaved = true
	camera.CameraType = Enum.CameraType.Scriptable
	local goal = CFrame.lookAt(centre + Vector3.new(15, 4.2, 1.2), centre + Vector3.new(0, 1.2, 0))
	setHold(player.Character, "Right", 1.05)
	b.npcTap = playAnim(b.npc, "Tap", 0.6)
	if not b.npcTap then
		setHold(b.npc, "Left", 1.05)
	end
	b.rivalSlaps = 0
	tween(camera, 0.5, { CFrame = goal }, Enum.EasingStyle.Sine)
	local stageCfg = Config.Stages[b.stage]
	local opponent = stageCfg.opponent or {}
	meterUI.Bar.Rival.Text = string.upper(opponent.name or stageCfg.name)
	setBattleHud(true)
	safe("duel start", function()
		duel:Start({
			playerName = player.DisplayName,
			userId = player.UserId,
			rivalName = opponent.name or stageCfg.name,
			rivalTitle = opponent.title or `Stage {stageCfg.order} rival`,
			rivalColor = stageCfg.color,
			rivalModel = b.rival,
			perTap = b.fight.perTap,
		})
	end)
	-- a brief tile sweep at the start
	if not reduced() then
		local tiles = stageModel:FindFirstChild("Tiles") :: Instance
		for _, t in tiles:GetChildren() do
			local tile = t :: BasePart
			local r = tonumber(string.sub(tile.Name, 5, 5)) or 0
			task.delay(r * 0.06, function()
				local orig = tile.Color
				tile.Color = Config.Stages[b.stage].color
				tween(tile, 0.3, { Color = orig })
			end)
		end
	end
end

local function captureFlash(tile: BasePart?, color: Color3)
	if not tile then
		return
	end
	local orig = tile.Color
	tile.Color = color
	tile.Material = Enum.Material.Neon
	task.delay(0.25, function()
		tile.Material = Enum.Material.SmoothPlastic
		tween(tile, 0.3, { Color = orig })
	end)
end

local function brilliantRing(at: Vector3)
	if reduced() then
		return
	end
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.4, 3, 3)
	ring.CFrame = CFrame.new(at + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(30, 215, 200)
	ring.Transparency = 0.1
	ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch = true, false, false, false
	ring.Parent = fxFolder
	tween(ring, 0.55, { Size = Vector3.new(0.2, 26, 26), Transparency = 1 }, Enum.EasingStyle.Quint)
	task.delay(0.6, function()
		ring:Destroy()
	end)
end

-- Result panel ----------------------------------------------------------------------
local resultFace = face(Panels.Result)
local resultPrimary: () -> () = function() end
local resultSecondary: () -> () = function() end
hookButton(resultFace.Primary, function()
	resultPrimary()
end)
hookButton(resultFace.Secondary, function()
	resultSecondary()
end)

local function showResult(r: any)
	local st = Config.Stages[r.stage]
	local title = face(resultFace.Title)
	setPreviewModel(resultFace.Rival, st.rival, Models.CHARCOAL, st.color)
	local primary = face(resultFace.Primary)
	local retryIcon = primary:FindFirstChild("RetryIcon")
	if retryIcon then
		retryIcon.Visible = false
	end
	if r.outcome == "win" then
		title.Label.Text = "Victory!"
		title.BackgroundColor3 = Hud.Colors.gold
		resultFace.Line1.Text = `{st.name} defeated!`
		resultFace.Line2.Text = if r.reward > 0 then `+{r.reward} Wins` else "Practice win (already cleared)"
		resultFace.Line2.TextColor3 = if r.reward > 0 then Hud.Colors.gold else Color3.new(1, 1, 1)
		if r.unlocked then
			resultFace.Line2.Text ..= ` · {Config.Stations[r.unlocked].name} unlocked!`
		end
		-- next useful action
		local nxt = nextStage()
		if not S.Sets.Marble and S.Wins >= Config.Sets.Marble.price then
			primary.Label.Text = "Buy Marble"
			primary.BackgroundColor3 = Hud.Colors.cyan
			resultPrimary = function()
				selectedSet = "Marble"
				refreshSets()
				showPanel("Sets")
			end
		elseif nxt and S.Power >= Config.Stages[nxt].power then
			primary.Label.Text = `Next: Stage {stageNumber(nxt)}`
			primary.BackgroundColor3 = Hud.Colors.green
			resultPrimary = function()
				closePanels()
				guide.customTarget = (Stages[nxt]:FindFirstChild("Zone") :: BasePart).Position
			end
		else
			primary.Label.Text = "Train more"
			primary.BackgroundColor3 = Hud.Colors.green
			resultPrimary = function()
				closePanels()
				Net.Request("Return")
			end
		end
		face(resultFace.Secondary).Label.Text = "Close"
		resultSecondary = closePanels
	else
		local tie = r.outcome == "tie"
		title.Label.Text = if tie then "Draw!" else "Defeat"
		title.BackgroundColor3 = if tie then Hud.Colors.purple else Hud.Colors.red
		resultFace.Line1.Text = if tie then "Exactly even! Free retry." else `{st.name} won this time`
		resultFace.Line2.Text = "You keep your Power and Wins"
		resultFace.Line2.TextColor3 = Color3.new(1, 1, 1)
		primary.Label.Text = "    Retry"
		primary.BackgroundColor3 = Hud.Colors.red
		if retryIcon then
			retryIcon.Visible = true;
			(retryIcon :: any).Position = UDim2.new(0, 22, 0.5, -20)
		end
		resultPrimary = function()
			closePanels()
			challenge(r.stage)
		end
		face(resultFace.Secondary).Label.Text = "Back to hub"
		resultSecondary = function()
			closePanels()
			Net.Request("Return")
		end
	end
	showPanel("Result")
end

challenge = function(stageId: string)
	if battle then
		return
	end
	local r = Net.Request("Challenge", stageId)
	if not r.ok then
		local why = {
			NeedPower = `Need {Config.Stages[stageId].power} Power. Train more!`,
			Locked = "Clear the stage before this one first",
			TooFar = "Walk up to the battle pad",
			Busy = "Finish your current battle first",
			NotLoaded = "Loading your progress...",
		}
		message(why[r.code] or "Try again", Color3.fromRGB(255, 210, 90))
		return
	end
	local d = r.data
	battle = {
		id = d.id, stage = d.stage, fight = d.fight, sent = 0, serverTaps = 0, serverMeter = 50, display = 50,
		t = 0, start = os.clock(), ended = false, lastMove = 0,
	}
	bucket.tokens = Config.Input.tapBurst
	closePanels()
	startBattleScene(battle)
	refreshContext()
	if d.book then
		showBadge("Book")
	end
	log(`battle {d.id} started`)
end

Net.On("Battle", function(p: any)
	if not battle or p.id ~= battle.id then
		return
	end
	battle.serverMeter, battle.serverTaps, battle.t = p.meter, p.taps, p.t
	for _, key in p.badges or {} do
		showBadge(key)
	end
end)

Net.On("BattleEnd", function(p: any)
	local b = battle
	if not b or p.id ~= b.id then
		return
	end
	b.ended = true
	b.outcome = p.outcome
	battle = nil
	if p.outcome == "cancelled" then
		endBattleScene(b)
		refreshContext()
		return
	end
	b.serverMeter = p.meter
	local stageCfg = Config.Stages[b.stage]
	if p.outcome == "win" and stageCfg and stageCfg.boss then
		-- L moment (vault 06 §2): dim, rays, title, confetti, one white flash
		task.delay(0.9, function()
			safe("boss moment", function()
				FeelKit.Moment(gui :: ScreenGui, "L", `YOU BEAT {string.upper((stageCfg.opponent or {}).name or stageCfg.name)}!`, { reduced = reduced, feel = feel })
			end)
		end)
	end
	local brilliant = table.find(p.badges or {}, "Brilliant") ~= nil
	for _, key in p.badges or {} do
		if key ~= "Brilliant" then
			showBadge(key)
		end
	end
	-- beat 1: the capture lands
	local rivalPos = b.rival and b.rival:GetPivot().Position or Vector3.zero
	if p.outcome == "win" and b.piece then
		local from = b.piece:GetPivot()
		local to = CFrame.new(rivalPos) * (from - from.Position)
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local a = math.clamp((os.clock() - t0) / 0.32, 0, 1)
			local pos = from.Position:Lerp(to.Position, 1 - (1 - a) ^ 3) + Vector3.new(0, math.sin(a * math.pi) * 3 * (b.tile or 4) / 4, 0)
			if b.piece and b.piece.Parent then
				b.piece:PivotTo(CFrame.new(pos) * (from - from.Position))
			end
			if a >= 1 then
				conn:Disconnect()
			end
		end)
		task.delay(0.3, function()
			if b.rival then
				for _, part in b.rival:GetDescendants() do
					if part:IsA("BasePart") then
						tween(part, 0.3, { Transparency = 1 })
					end
				end
			end
			captureFlash(b.model and tileAt(b.model, rivalPos), Color3.fromRGB(255, 240, 150))
			play("Capture")
			if brilliant then
				-- beat 2: the turquoise ring; beat 3: the badge and its own sound
				task.delay(0.12, function()
					brilliantRing(rivalPos)
				end)
				task.delay(0.45, function()
					showBadge("Brilliant")
					play("Brilliant")
				end)
			else
				play("Win")
			end
		end)
	elseif p.outcome == "lose" and b.rival and b.piece then
		local from = b.rival:GetPivot()
		local target = b.piece:GetPivot().Position
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local a = math.clamp((os.clock() - t0) / 0.35, 0, 1)
			local pos = from.Position:Lerp(target, 1 - (1 - a) ^ 3) + Vector3.new(0, math.sin(a * math.pi) * 2 * (b.tile or 4) / 4, 0)
			if b.rival and b.rival.Parent then
				b.rival:PivotTo(CFrame.new(pos) * (from - from.Position))
			end
			if a >= 1 then
				conn:Disconnect()
			end
		end)
		task.delay(0.32, function()
			if b.piece then
				for _, part in b.piece:GetDescendants() do
					if part:IsA("BasePart") then
						tween(part, 0.3, { Transparency = 1 })
					end
				end
			end
			captureFlash(b.model and tileAt(b.model, target), Color3.fromRGB(255, 90, 90))
			play("Lose")
		end)
	end
	task.delay(if brilliant then 1.5 else 1.0, function()
		endBattleScene(b)
		refreshContext()
		showResult(p)
	end)
	log(`battle {p.id}: {p.outcome} +{p.reward or 0} wins`)
end)

---------------------------------------------------------------------------
-- Server state
---------------------------------------------------------------------------
local firstState = true
local function applyState(snap: any)
	if not snap or not snap.loaded then
		return
	end
	local before = { Sets = S.Sets, Equipped = S.Equipped }
	for k, v in snap do
		S[k] = v
	end
	S.Settings = S.Settings or { Music = true, Sound = true, Reduced = false }
	setCounters(firstState)
	firstState = false
	for _, fn in listeners do
		safe("listener", fn)
	end
	local _ = before
end
onState(refreshProgress)
onState(refreshGallery)
onState(refreshStages)
onState(refreshGuide)
onState(refreshHudStage)
local levelFirst = true
onState(function()
	local level, progress
	if Config.Level then
		level, progress = Config.Level(S.Power, S.Promotions or 0)
	else
		level, progress = FeelKit.Level(S.Power)
	end
	feel:SetLevel(level, progress, levelFirst)
	if not levelFirst and feel.level and level > (feel.lastPlayedLevel or level - 1) then
		play("Chime", 1 + math.min(level, 20) * 0.02)
	end
	feel.lastPlayedLevel = level
	levelFirst = false
end)
onState(function()
	if openPanel == "Sets" then
		refreshSets()
	elseif openPanel == "Board" then
		refreshBoard()
	end
end)
Net.On("State", applyState)
task.spawn(function()
	for _ = 1, 20 do
		local r = Net.Request("Hello")
		if r.ok and r.data and r.data.loaded then
			applyState(r.data)
			return
		end
		task.wait(0.5)
	end
end)

---------------------------------------------------------------------------
-- Frame loop: context, belts, run anim, meter, guide arrows, gallery motion
---------------------------------------------------------------------------
local lastContext = 0
local lastReturn = 0
local spotlightPhase = 0
RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	if now - lastContext > 0.1 then
		lastContext = now
		safe("context", refreshContext)
		-- Return pads
		local r = root()
		if r and not battle and now - lastReturn > 3 then
			for _, m in Stages:GetChildren() do
				if not Config.Stages[m.Name] then
					continue -- decorative future gates have no rival yet
				end
				local ret = m:FindFirstChild("Return") :: BasePart?
				if ret and inside(r.Position, ret, 0.5) then
					lastReturn = now
					task.spawn(Net.Request, "Return")
				end
			end
		end
	end

	-- training: run animation and belt speed for me and for other players
	local myTraining = ctx.kind == "station" and now < trainingUntil
	if myTraining then
		if not runTrack then
			runTrack = loadRun()
		end
		if runTrack and not runTrack.IsPlaying then
			runTrack:Play(0.15, 1, 1.25)
		end
	elseif runTrack and runTrack.IsPlaying then
		runTrack:Stop(0.25)
	end
	local active: { [string]: boolean } = {}
	if myTraining then
		active[ctx.id] = true
	end
	for _, other in Players:GetPlayers() do
		local t = other:GetAttribute("Training")
		if other ~= player and type(t) == "string" then
			active[t] = true
		end
	end
	for id, belt in belts do
		belt.target = if active[id] then 9 else 0
		-- ease toward target: smooth start, keeps moving between taps, eases to a stop
		belt.speed += (belt.target - belt.speed) * math.min(1, dt * (if belt.target > belt.speed then 4 else 2))
		if belt.speed > 0.05 then
			belt.offset = (belt.offset + belt.speed * dt) % 1.04
			local chassis = belt.model:FindFirstChild("Chassis") :: BasePart
			for part, rel in belt.base do
				local p = rel.Position
				local z = ((p.Z + 5.2 + belt.offset) % 10.4) - 5.2
				part.CFrame = chassis.CFrame * CFrame.new(p.X, p.Y, z)
			end
		end
		-- console light: faint idle breathing, brighter while used
		local screen = belt.model:FindFirstChild("Screen") :: BasePart?
		local light = screen and screen:FindFirstChild("ConsoleLight") :: PointLight?
		if light then
			light.Brightness = if active[id] then 1.4 else 0.35 + 0.15 * math.sin(now * 2 * math.pi / 3)
		end
	end

	-- battle meter: confirmed value + this client's unconfirmed accepted taps
	if battle then
		local b = battle
		local predicted = math.clamp(b.serverMeter + (b.sent - b.serverTaps) * b.fight.perTap, 0, 100)
		b.display += (predicted - b.display) * math.min(1, dt * 14)
		local frac = b.display / 100
		mBar.Fill.Size = UDim2.fromScale(math.max(frac, 0.02), 1)
		mBar.Knob.Position = UDim2.fromScale(frac, 0.5)
		local leading = b.display >= 50
		mBar.You.TextColor3 = if leading then Color3.fromRGB(255, 255, 160) else Color3.new(1, 1, 1)
		mBar.Rival.TextColor3 = if leading then Color3.new(1, 1, 1) else Color3.fromRGB(255, 220, 220)
		meterUI.Hint.Visible = b.display < Config.Badges.danger[1].enter and b.t > Config.Badges.openingQuiet
		local elapsed = math.max(b.t, now - b.start)
		meterUI.Timer.Text = tostring(math.max(0, math.ceil(b.fight.timeout - elapsed)))
		duel:Update(dt, b.display, Config.Pressure(b.fight, elapsed), elapsed)
		-- rival move every ~1.7 s once pressure starts
		if elapsed > b.fight.grace and now - b.lastMove > 1.7 then
			b.lastMove = now
			rivalMove(b)
		end
		-- the rival slaps the clock at its pressure rate
		if b.npcTap then
			b.npcTap:AdjustSpeed(math.clamp(Config.Pressure(b.fight, elapsed) / b.fight.perTap * 0.5, 0.6, 2.4))
		end
		if elapsed > b.fight.grace and not b.ended then
			b.rivalSlaps = (b.rivalSlaps or 0) + dt * Config.Pressure(b.fight, elapsed) / b.fight.perTap
			if b.rivalSlaps >= 1 then
				b.rivalSlaps -= 1
				if not b.npcTap then
					slap(b.npc, "Left")
				end
				pressButton(b, "ClockButtonB")
			end
		end
	end
	stepArms(dt)

	-- guide arrows: a floating chain of chevrons from the player toward the target
	local r = root()
	local target = guide.customTarget or (if guide.step <= 3 then guide.target else nil)
	if guide.customTarget and r and (r.Position - guide.customTarget).Magnitude < 14 then
		guide.customTarget = nil
	end
	if r and target and not battle and (r.Position - target).Magnitude > 10 then
		local from = r.Position - Vector3.new(0, 1.2, 0)
		local flat = Vector3.new(target.X - from.X, 0, target.Z - from.Z)
		local dir = flat.Unit
		for i, a in arrows do
			local d = 5 + (i - 1) * 4 + (now * 3 % 4)
			if d < flat.Magnitude - 3 then
				local pos = from + dir * d + Vector3.new(0, 0.6 + math.sin(now * 3 + i) * 0.15, 0)
				a.CFrame = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(-math.pi / 2, 0, 0)
				a.Transparency = 0.15 + math.max(0, (i - 5) * 0.2)
			else
				a.Transparency = 1
			end
		end
	else
		for _, a in arrows do
			a.Transparency = 1
		end
	end

	-- gallery: slow bob and turn of featured pieces, orbiting beads; the nameplate stays still
	for id, entry in gallery do
		local bob = math.sin(now * 1.6 + entry.phase) * 0.35
		local turn = math.sin(now * 0.5 + entry.phase) * 0.35
		entry.model:PivotTo(entry.base * CFrame.new(0, bob + 0.6, 0) * CFrame.Angles(0, turn, 0))
		if entry.orbit then
			for i, bead in entry.orbit do
				local a = now * 1.4 + i * (math.pi * 2 / #entry.orbit)
				bead.CFrame = CFrame.new(entry.core + Vector3.new(math.cos(a) * 2.6, math.sin(a * 2) * 0.6 + bob, math.sin(a) * 2.6))
			end
		end
		if entry.glow then
			entry.glow.Transparency = 0.5 + 0.08 * math.sin(now * 2)
		end
	end

	-- ready stage pads glow; spotlit HUD button breathes
	spotlightPhase += dt
	for _, m in Stages:GetChildren() do
		local glow = m:FindFirstChild("PadGlow") :: BasePart?
		if glow then
			glow.Transparency = if glow:GetAttribute("Ready") then 0.25 + 0.2 * math.sin(now * 3) else 0.75
		end
	end
	local setsStroke = face(Rail.SetsButton):FindFirstChildOfClass("UIStroke") :: UIStroke
	if Rail.SetsButton:GetAttribute("Spotlight") then
		setsStroke.Color = Color3.new(1, 1, 1)
		setsStroke.Thickness = 3 + 2 * (0.5 + 0.5 * math.sin(spotlightPhase * math.pi * 2 / 1.2))
	else
		setsStroke.Color = Color3.fromRGB(28, 26, 40)
		setsStroke.Thickness = 3
	end
end)

log("client ready")
