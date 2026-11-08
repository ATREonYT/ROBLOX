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
local ChessItems = require(Kit:WaitForChild("ChessItems"))
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
G.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets

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
	-- the outline must fade with the text, or it stays behind as an unreadable dark strip (audit Nov 8)
	local outline = t:FindFirstChildOfClass("UIStroke")
	if outline then
		outline.Transparency = 0
	end
	local sc = t:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", t)
	sc.Scale = 0.6
	tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(1.8, function()
		if t.Text == textValue then
			tween(t, 0.3, { TextTransparency = 1 })
			if outline then
				tween(outline, 0.3, { Transparency = 1 })
			end
		end
	end)
end

-- 1v1 duel layer: VS cards, taps per second, combo, sparks, danger edges (Kit/DuelHud)
local duel = DuelHud.new(gui :: ScreenGui, { tween = tween, reduced = reduced, message = message })
-- The reference duel screen (Kit/DuelBar, Nov 8): the saved StarterGui copy, or one built here.
local duelUI: any = playerGui:WaitForChild("DuelBar", 3) or require(Kit:WaitForChild("DuelBar")).Build(playerGui)
duelUI.Enabled = false
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
	local scale = math.clamp(math.min(vp.X / 1330, vp.Y / 861), 0.5, 1.3)
	if isTouch then
		scale = math.clamp(math.min(vp.X / 1140, vp.Y / 640), 0.5, 1.1)
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
		-- the thumb button lives on the right edge on phones, so the paid offers fold away
		G.RightOffers.Offer1.Visible = false
		G.RightOffers.Offer2.Visible = false
	else
		MainHolder.Position = UDim2.new(1, -22, 1, -22)
		MainHolder.Size = UDim2.fromOffset(150, 100) -- fits right of the auto clickers at the larger HUD scale
		G.KeyHint.Visible = true
		G.RightOffers.Offer1.Visible = true
		G.RightOffers.Offer2.Visible = true
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
	if st.unlock and st.unlock.stage and not S.Cleared[st.unlock.stage] then
		return false, `Clear Stage {string.sub(st.unlock.stage, -1)} to unlock`
	end
	local need = Config.StationRebirths(id)
	if (S.Promotions or 0) < need then
		return false, `Needs {need} Rebirth` .. (if need > 1 then "s" else "")
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
	-- the sign of the machine you stand on would sit over the guide line: hide it while you train
	local onStation = if kind == "station" then id else nil
	if onStation ~= ctx.signHidden then
		for _, sid in { ctx.signHidden, onStation } do
			local m = sid and Stations:FindFirstChild(sid)
			local a = m and m:FindFirstChild("LabelAnchor")
			local bb = a and a:FindFirstChild("Label") :: BillboardGui?
			if bb then
				bb.Enabled = sid ~= onStation
			end
		end
		ctx.signHidden = onStation
	end
	local keyHint = if isTouch then "" else "Press E or click"
	-- the result card owns the screen: no TRAIN/CHALLENGE button behind it
	local covering = false
	for _, n in { "ResultPanel", "SetsPanel", "BoardPanel", "SettingsPanel" } do
		local p = G:FindFirstChild(n)
		if p and p:IsA("GuiObject") and p.Visible then
			covering = true
		end
	end
	if kind ~= "battle" and covering then
		setMain(false)
		contextLine("")
		G.KeyHint.Text = ""
		return
	end
	if kind == "battle" then
		setMain(true, "CLICK TO WIN", "Push the meter!", Hud.Colors.red)
		contextLine("") -- the meter is the only thing to read in a duel
		G.KeyHint.Text = keyHint
	elseif kind == "station" then
		local st = Config.Stations[id]
		local open, why = stationOpen(id)
		if open then
			-- no TRAIN button (Alex, Nov 8): the treadmill pays by itself while you stand on it
			local perSec = Format.Short(Config.Gain(id) * Config.PowerMult(S.Promotions or 0, S.Passes) / Config.TreadmillTick)
			setMain(false)
			contextLine(`{st.name} · +{perSec} Elo every second`)
		else
			setMain(false)
			contextLine(`{st.name} · {why}`, Color3.fromRGB(255, 210, 90))
		end
		G.KeyHint.Text = ""
	elseif kind == "stage" then
		local st = Config.Stages[id]
		local n = stageNumber(id)
		local first = not S.Cleared[id]
		if not stageOpen(id) then
			setMain(false)
			contextLine(`Stage {n} · Clear Stage {n - 1} first`, Color3.fromRGB(255, 210, 90))
		elseif S.Power < st.power then
			setMain(false)
			contextLine(`{st.name} · Need {Format.Short(st.power)} Elo (you have {Format.Short(S.Power)})`, Color3.fromRGB(255, 210, 90))
		else
			-- the server pays every win (Core.StepBattle), scaled by promotions and 2x Wins; a first clear also unlocks
			local pay = math.floor(st.reward * Config.WinsMult(S.Promotions or 0, S.Passes))
			local unlockName = st.unlocks and Config.Stations[st.unlocks] and Config.Stations[st.unlocks].name
			-- Nov 8 (reference): no CHALLENGE button. Walk up to the rival and press Battle over his head.
			setMain(false)
			local _ = pay
			contextLine(`{st.name} · {Format.Short(S.Power)}/{Format.Short(st.power)} Elo · ` .. (if first and unlockName then `first win unlocks {unlockName}` elseif first then "first clear" else "cleared"))
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
	Bottom.Power.Row.Value.Text = `{Format.Short(math.floor(v + 0.5))} Elo`
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

-- Elo pop-ups like the reference's Subscribers: icon + "+N" lands at a random spot around your
-- character on screen at (almost) full size, drifts up a little, then shrinks and fades (0.8 s in all).
-- One pop per click, never merged (Alex's 240 fps clips, Nov 8; vault findings). Capped at 12 on screen.
local eloPops = Instance.new("ScreenGui")
eloPops.Name = "EloPops"
eloPops.ResetOnSpawn = false
eloPops.IgnoreGuiInset = true
eloPops.DisplayOrder = 5
eloPops.Parent = playerGui
local eloGT: any = nil
pcall(function()
	eloGT = require(ReplicatedStorage:WaitForChild("ChessEvolutionUI"):WaitForChild("GlyphText", 5) :: ModuleScript)
end)
local eloIconImage = ""
do
	local evo = game:GetService("StarterGui"):FindFirstChild("ChessEvolutionUI")
	local ic = evo and evo:FindFirstChild("PowerIcon", true)
	if ic and ic:IsA("ImageLabel") then
		eloIconImage = ic.Image
	end
end
local liveEloPops: { Frame } = {}
local lastTapPopAt = 0
local lastFxPopAt = 0 -- treadmill gains pop from the server's "Fx" push
local winsShownUntil = 0 -- while a result card or return toast is showing the Wins, no extra popup
-- Tap pop-ups live in the world now (build guide section 2, from Cannon Effects.floatingText):
-- Kit/TapPops, one "+N" per tap or treadmill tick at a random spot around you, never merged.
local tapPops = require(Kit:WaitForChild("TapPops")).new({ icon = eloIconImage, reduced = reduced })
local function eloPop(amount: number)
	local r = root()
	if r then
		tapPops:Pop(r, `+{Format.Short(amount)}`)
	end
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
		-- taps already showed their own pop the moment you clicked; only gains with no click
		-- behind them (the Auto Train pass) pop here
		if os.clock() - lastTapPopAt > 0.6 and os.clock() - lastFxPopAt > 0.6 then
			local gain = S.Power - shown.power
			safe("elo pop", function()
				eloPop(gain)
			end)
		end
	end
	if S.Wins > shown.wins and not first then
		local f = face(Rail.Wins)
		-- one celebration per grant: the result card and the return toast already show their Wins
		if os.clock() > winsShownUntil then
			feel:Popup(head, `+{Format.Short(S.Wins - shown.wins)} Wins`, "wins")
		end
		local sc = Rail.Wins:FindFirstChild("Press") :: UIScale
		sc.Scale = 1.15
		tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		local _ = f
	end
	shown.power, shown.wins = S.Power, S.Wins
end

-- Progress bar to the next rival
local function refreshProgress()
	local id = nextStage()
	-- The bar is the level bar (FeelKit:SetLevel moves it). This fills in its numbers, the Promotions count and the +N chip.
	local id = nextStage()
	if id then
		face(Rail.Stage).Value.Text = `Stage {stageNumber(id)} · {Config.Stages[id].name}`
	else
		face(Rail.Stage).Value.Text = "Board Run cleared!"
	end
	local _level, _frac, into, span = Config.Level(S.Power, S.Promotions or 0)
	Bottom.Progress.Bar.Count.Text = if span and span > 0 then `{Format.Short(math.floor(into))}/{Format.Short(math.ceil(span))}` else "MAX"
	face(Rail.Promos).Value.Text = Format.Short(S.Promotions or 0)
	local chip = Bottom.Progress:FindFirstChild("Level")
	if chip then
		chip.Face.Value.Text = `+{Format.Short(Config.TapGain(S.Equipped) * Config.PowerMult(S.Promotions or 0, S.Passes))}`
	end
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
local slap: (Model?, string) -> ()
local pressButton: (any, string) -> ()
local duelTap: (any) -> ()
local D: any = {} -- the reference duel's helpers (kept in one table: this script is near Luau's 200-locals limit)

-- An open menu or result card owns input: E / the action button must not start a duel or
-- train behind it (playtest Nov 8: extra taps after a win started a hidden second duel).
local MODALS_HUD = { "ResultPanel", "SetsPanel", "BoardPanel", "SettingsPanel" }
local MODALS_UI = { "Evolve", "Rebirth", "Shop", "ShopCatalog", "ShopWideOffers", "Daily", "Rewards", "OfflineRewards", "SpinWheel" }
local resultLockUntil = 0 -- taps still in flight when a duel ends must not start the next one
local function modalOpen(): boolean
	for _, n in MODALS_HUD do
		local p = G:FindFirstChild(n)
		if p and p:IsA("GuiObject") and p.Visible then
			return true
		end
	end
	local ev = playerGui:FindFirstChild("ChessEvolutionUI")
	if ev then
		for _, n in MODALS_UI do
			local f = ev:FindFirstChild(n)
			if f and f:IsA("GuiObject") and f.Visible then
				return true
			end
		end
	end
	local loop = playerGui:FindFirstChild("ChessLoop")
	local lp = loop and loop:FindFirstChild("Panel")
	return lp ~= nil and lp:IsA("GuiObject") and lp.Visible
end

local function doAction(fromScreen: boolean?)
	refreshContext()
	if ctx.kind ~= "battle" and (modalOpen() or os.clock() < resultLockUntil) then
		return
	end
	if ctx.kind == "battle" and battle and not battle.ended then
		if os.clock() < (battle.goAt or 0) then
			return -- still counting down: taps count from GO!
		end
		pressMain()
		duelTap(battle) -- local feedback only (sparkles, bar knob); the server still counts the taps
		if takeLocalToken() then
			battle.sent += 1
			Net.Send("Tap", "battle", battle.id)
			tapSound()
			battle.kick = (battle.kick or 0) + 1
			battle.hand = if battle.hand == "Right" then "Left" else "Right"
			slap(player.Character, battle.hand)
			pressButton(battle, "ClockButtonA")
		end
	elseif ctx.kind == "stage" and MainHolder.Visible and not fromScreen then
		pressMain()
		challenge(ctx.id)
	elseif ctx.kind ~= "battle" then
		-- Tap anywhere (Alex, Nov 8): the equipped set's Elo, x rebirths and passes. Treadmills pay by themselves.
		if takeLocalToken() then
			Net.Send("Tap", "train", "Tap")
			lastTapPopAt = os.clock()
			local perTap = Config.TapGain(S.Equipped) * Config.PowerMult(S.Promotions or 0, S.Passes)
			safe("elo pop", function()
				eloPop(perTap)
			end)
			tapSound()
		end
	end
end

-- Which open treadmill deck am I standing on (nil if none)?
local function standingOnDeck(): string?
	if ctx.kind ~= "station" or not ctx.id or battle then
		return nil
	end
	local m = Stations:FindFirstChild(ctx.id)
	local deck = m and m:FindFirstChild("Deck") :: BasePart?
	local r = root()
	if not deck or not r or not inside(r.Position, deck, 0.5) or not stationOpen(ctx.id) then
		return nil
	end
	return ctx.id
end

-- Tap anywhere on the screen (not on a button) to train while on a treadmill, or to push in a duel,
-- like the reference. Taps on UI are already handled by the UI (gameProcessed).
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	-- a screen tap never starts a duel; only the CHALLENGE button or E does
	safe("screen tap", function()
		doAction(true)
	end)
end)

-- Treadmill gains (server "Fx" push): one pop per gain while you stand on an open treadmill.
Net.On("Fx", function(p: any)
	if type(p) == "table" and p.kind == "tread" and type(p.gain) == "number" then
		lastFxPopAt = os.clock()
		safe("tread pop", function()
			eloPop(p.gain)
		end)
	end
end)

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

-- The map streams in, so each case is set up when it arrives (and again if it streams back in).
local refreshGallery: () -> ()
local buyOrEquip: (string) -> ()
local function setupDisplay(display: Instance)
	local id = display.Name
	local set = Config.Sets[id]
	if not set or display:FindFirstChild("FX") then
		return
	end
	local featured = display:WaitForChild("Featured", 10) :: Model?
	local anchor = display:WaitForChild("PieceAnchor", 10) :: BasePart?
	if not featured or not anchor or display:FindFirstChild("FX") or not display.Parent then
		return
	end
	-- each set has its own chess item (ChessItems): swap in the item if the map still holds an old piece
	if featured:GetAttribute("SetId") ~= id then
		local item = ChessItems.Build(id, 1.05, anchor.CFrame * CFrame.new(0, -0.4, 0) * CFrame.Angles(0, math.pi, 0)) -- board face toward the path
		item.Name = "Featured"
		featured:Destroy()
		item.Parent = display
		featured = item
	end
	local entry: any = { model = featured, base = featured:GetPivot(), phase = set.order * 0.9, fx = {} }
	if not set.available then
		addLock(display :: Model)
	end
	local holder = Instance.new("Folder")
	holder.Name = "FX"
	holder.Parent = display
	ChessItems.AddFx(featured, id, 1)
	if set.fx == "orbit" or id == "Cosmic" then
		-- Gold: three coins circle the board; Cosmic: three small moons
		entry.orbit = {}
		for _ = 1, 3 do
			table.insert(entry.orbit, neonBall(holder, if id == "Gold" then 0.6 else 0.45, set.accent, 0))
		end
	end
	entry.core = featured:GetPivot().Position
	gallery[id] = entry
	-- the case is clickable (reference: click a phone to buy or equip it)
	local glass = display:WaitForChild("Glass", 5) :: BasePart?
	if glass and not glass:FindFirstChildOfClass("ClickDetector") then
		glass.CanQuery = true
		local cd = Instance.new("ClickDetector")
		cd.MaxActivationDistance = 60
		cd.Parent = glass
		local hl = Instance.new("Highlight")
		hl.FillTransparency = 1
		hl.OutlineColor = Color3.new(1, 1, 1)
		hl.Enabled = false
		hl.Adornee = featured
		hl.Parent = holder
		cd.MouseHoverEnter:Connect(function()
			hl.Enabled = true
		end)
		cd.MouseHoverLeave:Connect(function()
			hl.Enabled = false
		end)
		cd.MouseClick:Connect(function()
			safe("itemClick", function()
				buyOrEquip(id)
			end)
		end)
	end
	if refreshGallery then
		refreshGallery()
	end
end
for _, display in Displays:GetChildren() do
	task.spawn(safe, "gallery", function()
		setupDisplay(display)
	end)
end
Displays.ChildAdded:Connect(function(display)
	task.spawn(safe, "gallery", function()
		setupDisplay(display)
	end)
end)

function refreshGallery()
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
		-- Nov 8 layout: each rival stands right in front of his own gate; it opens once you beat him
		local passed = S.Cleared[id] == true or (barrier ~= nil and barrier:GetAttribute("Smashed") == true)
		if barrier then
			barrier.CanCollide = not passed
			barrier.Transparency = if passed then 1 else 0.5
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
	a.Size = Vector3.new(0.2, 0.8, 0.9)
	a.Color = Color3.new(1, 1, 1)
	a.Material = Enum.Material.Neon
	a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch, a.CastShadow = true, false, false, false, false
	a.Transparency = 1
	a.Parent = fxFolder
	arrows[i] = a
end
local guide: any = { step = 0, target = nil, customTarget = nil, sub = nil }
-- Step 4 ends on the first confirmed Elo gain with Marble equipped, so the player sees +2 land.
-- A player who joins with Marble already equipped has done it before: skip the step.
local marbleTrained: boolean? = nil
local marbleBase: number? = nil
local function guideTarget(): (number, string?, Vector3?)
	if marbleTrained == nil and S.loaded then
		marbleTrained = S.Equipped == "Marble" and S.Sets.Marble == true
	end
	if S.Equipped == "Marble" and not marbleTrained then
		if marbleBase == nil then
			marbleBase = S.Power
		elseif S.Power > marbleBase then
			marbleTrained = true
		end
	else
		marbleBase = nil
	end
	-- Big tutorial (Alex, Nov 8): one short order in big letters, and a small line under it with
	-- the exact numbers. guide.sub carries the small line.
	local s1, s2 = Config.Stages.Stage1, Config.Stages.Stage2
	local p = Format.Short(math.floor(S.Power))
	if S.Power < s1.power and not S.Cleared.Stage1 then
		local deck = Stations.PawnMill:FindFirstChild("Deck") :: BasePart
		guide.sub = if S.Power < 4 then "or stand on the green treadmill for free Elo" else `{p}/{s1.power} Elo to fight {s1.name}`
		return 1, "TAP ANYWHERE FOR ELO!", if deck then deck.Position else nil -- the map may still be arriving
	elseif not S.Cleared.Stage1 then
		local zone = (Stages.Stage1:FindFirstChild("RivalStand") or Stages.Stage1:FindFirstChild("Zone")) :: BasePart
		guide.sub = `You have {p} Elo! Walk up to {s1.name} and press Battle`
		return 2, `BATTLE {string.upper(s1.name)}!`, zone.Position
	elseif not S.Sets.Marble then
		local plinth = Displays.Marble:FindFirstChild("Plinth") :: BasePart
		local price = Config.Sets.Marble.price
		if S.Wins >= price then
			guide.sub = `Tap Evolve  -  Marble doubles your Elo per tap`
			return 3, "BUY THE MARBLE SET!", plinth.Position
		end
		guide.sub = `{Format.Short(S.Wins)}/{price} Wins for the Marble Set`
		return 3, "WIN DUELS FOR WINS!", plinth.Position
	elseif S.Equipped ~= "Marble" and not marbleTrained then
		local plinth = Displays.Marble:FindFirstChild("Plinth") :: BasePart
		guide.sub = "Tap Evolve and equip it"
		return 4, "EQUIP THE MARBLE SET!", plinth.Position
	elseif not marbleTrained then
		guide.sub = `Marble gives +{Config.TapGain("Marble")} Elo every tap`
		return 4, "TAP ANYWHERE!", nil
	elseif not S.Cleared.Stage2 and Stages:FindFirstChild("Stage2") then
		local zone = (Stages.Stage2:FindFirstChild("RivalStand") or Stages.Stage2:FindFirstChild("Zone")) :: BasePart?
		if S.Power >= s2.power then
			guide.sub = `Walk up to {s2.name} and press Battle`
			return 5, `BATTLE {string.upper(s2.name)}!`, if zone then zone.Position else nil
		end
		guide.sub = `{p}/{s2.power} Elo to fight {s2.name}`
		return 5, "TAP FOR MORE ELO!", nil
	elseif Config.Guide[6] and not S.TutorialDone and (S.Promotions or 0) < 1 then
		local needP, needW = Config.PromotionCost(S.Promotions or 0)
		if S.Power >= needP and S.Wins >= needW then
			guide.sub = "Tap Rebirth  -  unlocks Knight Sprint and +50% Elo"
			return 6, "REBIRTH NOW!", nil
		end
		guide.sub = `{p}/{Format.Short(needP)} Elo and {Format.Short(S.Wins)}/{needW} Wins  -  unlocks Knight Sprint`
		return 6, "GET READY TO REBIRTH!", nil
	end
	guide.sub = nil
	return #Config.Guide + 1, nil, nil
end
local function refreshGuide()
	local step, textValue, target = guideTarget()
	guide.step, guide.target = step, target
	local holder = G.Guide
	local fighting = S.battle ~= nil or (battle ~= nil and not battle.ended)
	if step > #Config.Guide or S.TutorialDone or fighting then
		holder.Visible = false -- the duel owns the screen; the guide comes back after it
	else
		holder.Visible = true
		local f = face(holder)
		f.Step.Text = `STEP {step}/{#Config.Guide}`
		local sub = f:FindFirstChild("Sub") :: TextLabel?
		if sub then
			sub.Text = guide.sub or ""
		end
		if f.Text.Text ~= textValue then
			f.Text.Text = textValue
			-- a new order pops in big, then settles (one pop per change, no flashing)
			local pop = f:FindFirstChild("Pop") :: UIScale?
			if pop then
				pop.Scale = 1.3
				tween(pop, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
			end
		end
	end
	-- spotlight the Chess Sets button on the buy/equip steps
	local sets = Rail.SetsButton
	sets:SetAttribute("Spotlight", step == 3 and S.Wins >= Config.Sets.Marble.price or (step == 4 and S.Equipped ~= "Marble"))
	local loop = playerGui:FindFirstChild("ChessLoop")
	local promote = loop and loop:FindFirstChild("PromoteBtn", true)
	if promote then
		promote:SetAttribute("Spotlight", step == 6)
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
		wins = { Rail.Wins, Rail.Promos },
		sets = { Rail.SetsButton },
		promote = { lr("PromoteBtn") },
		rest = { G.SettingsButton, G.TopBar, G.Wheel, G.RightOffers, G.Invite, lr("ShopBtn"), lr("DailyBtn"), lr("GiftBtn") },
	} :: any
end
local function refreshHudStage()
	local step = guide.step
	local done = S.TutorialDone == true or (S.Promotions or 0) >= 1 or step > #Config.Guide
	local show = {
		wins = done or S.Cleared.Stage1 == true or S.Wins > 0,
		sets = done or step >= 3,
		promote = done or step >= 6,
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
	pv.Mult.Text = `x{set.multiplier} Elo per tap`
	local stationId = currentStation()
	local st = Config.Stations[stationId]
	local _ = st
	pv.Change.Text = if selectedSet == S.Equipped
		then `Tap: +{Config.TapGain(selectedSet)} Elo per tap (equipped)`
		else `Tap: +{Config.TapGain(S.Equipped)} → +{Config.TapGain(selectedSet)} Elo per tap`
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

function buyOrEquip(id: string)
	if busy then
		return
	end
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
		local before = Config.TapGain(S.Equipped)
		local r = Net.Request("Equip", id)
		busy = false
		if r.ok then
			local after = Config.TapGain(id)
			toast(`Tap: +{before} → +{after} Elo per tap!`, Color3.fromRGB(150, 255, 140))
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
			local mult = Config.PowerMult(S.Promotions or 0, S.Passes)
			toast(`{set.name} equipped! Tap: +{Format.Short(Config.TapGain(S.Equipped) * mult)} -> +{Format.Short(Config.TapGain(id) * mult)} Elo per tap`, Hud.Colors.cyan)
			log(`bought {id}`)
			Net.Request("Equip", id) -- a new set goes straight into your hand
		else
			message(if r.code == "NeedWins" then `Need {set.price} Wins` else "Could not buy. Try again.")
		end
	else
		busy = false
		message(`Need {set.price} Wins. Beat rivals to earn Wins!`)
	end
end
hookButton(setsFace.Preview.Action, function()
	buyOrEquip(selectedSet)
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
		f.Info.Text = `{Format.Short(st.power)} Elo · +{st.reward} Wins a win`
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
hookButton(G.SettingsButton, function()
	refreshSettings()
	showPanel("Settings")
end)
-- The new UI (StarterGui.ChessEvolutionUI) opens these panels through a BindableEvent.
do
	local ui = ReplicatedStorage:FindFirstChild("ChessEvolutionUI")
	local ev = ui and ui:FindFirstChild("OpenPanel")
	if ev and ev:IsA("BindableEvent") then
		ev.Event:Connect(function(name: string)
			if name == "Sets" then
				refreshSets()
				showPanel("Sets")
			elseif name == "Board" then
				refreshBoard()
				showPanel("Board")
			elseif name == "Settings" then
				refreshSettings()
				showPanel("Settings")
			elseif name == "Close" then
				if openPanel then
					closePanels()
				end
			end
		end)
	end
end

---------------------------------------------------------------------------
-- Battle scene
---------------------------------------------------------------------------
local meterUI = Bottom.Meter
local mBar = meterUI.Bar
local camSaved: any = nil

-- Nov 8 (reference): the whole HUD goes during a duel; only the duel bar shows.
D.hidden = {} :: { [ScreenGui]: boolean }
local function setBattleHud(on: boolean)
	if on then
		for _, g in playerGui:GetChildren() do
			if g:IsA("ScreenGui") and g ~= duelUI and g.Enabled then
				D.hidden[g] = true
				g.Enabled = false
			end
		end
		duelUI.Enabled = true
	else
		for g in D.hidden do
			if g.Parent then
				g.Enabled = true
			end
		end
		table.clear(D.hidden)
		duelUI.Enabled = false
	end
	meterUI.Visible = false
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
	tween(pop, 0.3, { Scale = 1 }, Enum.EasingStyle.Back) -- reference menu pop: 0.3 s back-out
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

-- Duel arms (Nov 8, vault note 17 section 4): code poses layered onto each joint's Transform in
-- PreSimulation, so they work on Motor6D rigs and on the 2026 AnimationConstraint player rigs
-- (where C0 can't be set). Each tap is a five-pose strike: hands over the board, wind up, slam,
-- overshoot, settle; the waist dips into the slam.
local arms: { [Model]: { [string]: any } } = {}
local function armOf(rig: Model?, side: string): any
	if not rig then
		return nil
	end
	arms[rig] = arms[rig] or {}
	local cache = arms[rig]
	if cache[side] and cache[side].joint.Parent then
		return cache[side]
	end
	local joint
	if side == "Waist" then
		local torso = rig:FindFirstChild("UpperTorso")
		joint = torso and torso:FindFirstChild("Waist")
	elseif side == "Root" then
		local lower = rig:FindFirstChild("LowerTorso")
		joint = lower and lower:FindFirstChild("Root")
	else
		local upper = rig:FindFirstChild(side .. "UpperArm")
		joint = upper and upper:FindFirstChild(side .. "Shoulder")
	end
	if not (joint and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint"))) then
		return nil
	end
	local a = { joint = joint, at = -1, hold = 0, holdNow = 0 }
	cache[side] = a
	return a
end
function D.strike(t: number): number
	if t < 0 or t > 0.26 then
		return 0
	elseif t < 0.05 then -- wind up
		local k = t / 0.05
		return 0.8 * (1 - (1 - k) ^ 2)
	elseif t < 0.085 then -- slam
		local k = (t - 0.05) / 0.035
		return 0.8 - 1.15 * k * k
	end
	local k = (t - 0.085) / 0.175 -- overshoot, then settle
	return -0.35 * (1 - k) ^ 2 * math.cos(k * math.pi * 1.5)
end
function pressButton(b: any, name: string)
	local tbl = b.model and (b.model:FindFirstChild("DuelTable") or b.model:FindFirstChild("DuelBoard"))
	local btn = tbl and tbl:FindFirstChild(name) :: BasePart?
	if btn then
		btn:SetAttribute("Press", os.clock())
	end
	-- a piece on that side of the board hops with the slam
	local pieces = tbl and tbl:FindFirstChild("Pieces")
	if pieces and not reduced() then
		local want = if name == "ClockButtonA" then "Player" else "Rival"
		local mine = {}
		for _, pc in pieces:GetChildren() do
			if pc:GetAttribute("Side") == want and not pc:GetAttribute("Hopping") then
				table.insert(mine, pc)
			end
		end
		local pc = mine[math.random(1, math.max(1, #mine))] :: Model?
		if pc then
			pc:SetAttribute("Hopping", true)
			local home = pc:GetPivot()
			local t0 = os.clock()
			local conn: RBXScriptConnection
			conn = RunService.RenderStepped:Connect(function()
				local k = math.clamp((os.clock() - t0) / 0.2, 0, 1)
				pc:PivotTo(home * CFrame.new(0, math.sin(k * math.pi) * 0.22, 0) * CFrame.Angles(0, k * math.pi * 0.5, 0))
				if k >= 1 then
					conn:Disconnect()
					pc:PivotTo(home)
					pc:SetAttribute("Hopping", nil)
				end
			end)
		end
	end
end
function slap(rig: Model?, side: string)
	local a = armOf(rig, side)
	if a then
		a.at = os.clock()
	end
	local w = armOf(rig, "Waist")
	if w then
		w.at = os.clock()
	end
	-- your own taps also lunge your body toward the board (build guide section 3)
	local rt = if rig and rig == player.Character then armOf(rig, "Root") else nil
	if rt then
		rt.at = os.clock()
	end
end
local function setHold(rig: Model?, side: string, hold: number)
	local a = armOf(rig, side)
	if a then
		a.hold = hold
	end
end
function D.animated(rig: Model): boolean
	local hum = rig:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	return animator ~= nil and #animator:GetPlayingAnimationTracks() > 0
end
local function releaseArms(rig: Model?)
	if rig and arms[rig] then
		if not D.animated(rig) then
			for _, a in arms[rig] do
				if a.joint.Parent then
					a.joint.Transform = CFrame.identity
				end
			end
		end
		arms[rig] = nil
	end
end
RunService.PreSimulation:Connect(function()
	local now = os.clock()
	for rig, parts in arms do
		if not rig.Parent then
			arms[rig] = nil
			continue
		end
		local animated = D.animated(rig)
		for key, a in parts do
			if not a.joint.Parent then
				continue
			end
			a.holdNow += (a.hold - a.holdNow) * 0.2
			local t = now - a.at
			local pose
			if key == "Root" then
				local l = if t < 0 then 0 elseif t < 0.08 then t / 0.08 elseif t < 0.23 then 1 - (t - 0.08) / 0.15 else 0
				pose = CFrame.new(0, 0, -0.35 * l * l * (3 - 2 * l))
			elseif key == "Waist" then
				local lean = if t > 0.05 and t < 0.26 then 0.14 * math.sin(math.pi * (t - 0.05) / 0.21) else 0
				pose = CFrame.Angles(-lean, 0, 0)
			else
				local angle = a.holdNow + D.strike(t)
				local roll = if key == "Right" then -0.25 else 0.25
				pose = CFrame.Angles(angle, 0, if angle > 0 then roll * math.min(1, angle) else 0)
			end
			a.joint.Transform = if animated then pose * a.joint.Transform else pose
		end
	end
end)
local function stepArms(_dt: number)
	-- clock buttons dip when slapped
	-- clock buttons dip when slapped
	for _, m in Stages:GetChildren() do
		local tbl = m:FindFirstChild("DuelTable") or m:FindFirstChild("DuelBoard")
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

-- Reference duel (Alex, Nov 8) ---------------------------------------------------------
-- You walk up to the rival in front of his gate and press Battle. The camera starts over his
-- shoulder, swings round to the side view of you both at the chess board, counts 3-2-1-GO (GO lands
-- on the server's Config.DuelIntro), then slowly pushes in while you tap. On a win he is flung
-- through his gate and the camera comes back behind you.
D.DUEL_HOLD = 0.35 -- the over-the-shoulder shot holds this long
D.DUEL_SWEEP = 1.0 -- then the camera swings round to the side view
D.DUEL_STEP = 0.7 -- each of 3, 2, 1
D.SIDE_DIST, D.SIDE_UP = 11, 4.6 -- the side view: distance and height from the middle of the duel
D.GOLD_COUNT = Color3.fromRGB(255, 206, 52)
D.GREEN_GO = Color3.fromRGB(96, 232, 64)

function D.duelGeometry(b: any, stageModel: Instance)
	local spot = stageModel:FindFirstChild("PlayerSpot") :: BasePart
	local stand = (stageModel:FindFirstChild("RivalStand") or stageModel:FindFirstChild("RivalPlate")) :: BasePart
	local them = stand.Position
	local me = Vector3.new(spot.Position.X, them.Y, spot.Position.Z)
	local axis = (them - me) * Vector3.new(1, 0, 1)
	axis = if axis.Magnitude > 0.1 then axis.Unit else Vector3.new(0, 0, -1)
	-- the camera stands on the side both players are turned toward (the open lane)
	local side = Vector3.yAxis:Cross(axis)
	if side:Dot(spot.CFrame.LookVector) < 0 then
		side = -side
	end
	b.me, b.them, b.axis, b.side = me, them, axis, side
	b.centre = (me + them) / 2 + Vector3.new(0, 3, 0)
	-- the intro shot: just behind the rival's shoulder, looking at you
	local startPos = them + axis * 2.6 - side * 1.5 + Vector3.new(0, 4.6, 0)
	local h = (startPos - b.centre) * Vector3.new(1, 0, 1)
	b.th0 = math.atan2(h:Dot(axis), h:Dot(side))
	b.r0 = h.Magnitude
	b.y0 = startPos.Y
	b.look0 = me + Vector3.new(0, 3.6, 0)
end

function D.introCam(b: any, e: number): CFrame
	local s = e * e * (3 - 2 * e)
	local th = b.th0 * (1 - s)
	local r = b.r0 + (D.SIDE_DIST - b.r0) * s ^ 1.6
	local y = b.y0 + (b.centre.Y + D.SIDE_UP - b.y0) * s
	local flat = b.side * math.cos(th) * r + b.axis * math.sin(th) * r
	local pos = Vector3.new(b.centre.X + flat.X, y, b.centre.Z + flat.Z)
	return CFrame.lookAt(pos, b.look0:Lerp(b.centre + Vector3.new(0, 0.4, 0), s))
end

function D.sideCam(b: any, push: number): CFrame
	local pos = b.centre + b.side * (D.SIDE_DIST - push) + Vector3.new(0, D.SIDE_UP - push * 0.35, 0)
	return CFrame.lookAt(pos, b.centre + Vector3.new(0, 0.4, 0))
end

-- sparkles and a slow swirl around a fighter (Roblox's own particle pictures only)
function D.addAura(rig: Model?, color: Color3): { ParticleEmitter }
	local hrp = rig and rig:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return {}
	end
	local old = hrp:FindFirstChild("DuelAura")
	if old then
		old:Destroy()
	end
	local att = Instance.new("Attachment")
	att.Name = "DuelAura"
	att.Parent = hrp
	local sp = Instance.new("ParticleEmitter")
	sp.Name = "Sparkle"
	sp.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sp.Color = ColorSequence.new(color)
	sp.LightEmission = 1
	sp.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(1, 0) })
	sp.Lifetime = NumberRange.new(0.4, 0.8)
	sp.Speed = NumberRange.new(2, 5)
	sp.SpreadAngle = Vector2.new(180, 180)
	sp.Rate = if reduced() then 0 else 12
	sp.Parent = att
	local sw = Instance.new("ParticleEmitter")
	sw.Name = "Swirl"
	sw.Texture = "rbxasset://textures/particles/forcefield_vortex_main.dds"
	sw.Color = ColorSequence.new(color)
	sw.LightEmission = 0.8
	sw.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.4), NumberSequenceKeypoint.new(1, 3.4) })
	sw.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.5), NumberSequenceKeypoint.new(1, 1) })
	sw.Lifetime = NumberRange.new(0.5, 0.7)
	sw.Speed = NumberRange.new(0, 0)
	sw.Rotation = NumberRange.new(0, 360)
	sw.RotSpeed = NumberRange.new(-260, -200)
	sw.LockedToPart = true
	sw.Rate = if reduced() then 0 else 5
	sw.Parent = att
	return { sp, sw }
end

function D.dropAura(rig: Model?)
	local hrp = rig and rig:FindFirstChild("HumanoidRootPart")
	local att = hrp and hrp:FindFirstChild("DuelAura")
	if att then
		for _, e in att:GetChildren() do
			if e:IsA("ParticleEmitter") then
				e.Enabled = false
			end
		end
		task.delay(1, function()
			att:Destroy()
		end)
	end
end

-- the huge white "Stage N" that opens a duel (reference long recording, build guide section 3)
function D.showTitle(text: string)
	local t = duelUI:FindFirstChild("Title") :: TextLabel?
	if not t then
		return
	end
	local pop = t:FindFirstChild("Pop") :: UIScale?
	t.Text = text
	t.TextTransparency = 0
	local st = t:FindFirstChildOfClass("UIStroke")
	if st then
		st.Transparency = 0
	end
	t.Visible = true
	if pop then
		pop.Scale = if reduced() then 1 else 0.6
		tween(pop, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	task.delay(1.1, function()
		tween(t, 0.25, { TextTransparency = 1 })
		if st then
			tween(st, 0.25, { Transparency = 1 })
		end
		task.delay(0.26, function()
			t.Visible = false
		end)
	end)
end

function D.showCount(b: any, text: string, color: Color3, sound: string)
	if b.ended then
		return
	end
	local c = duelUI.Count
	c.Text = text
	c.TextColor3 = color
	c.Visible = true
	c.Pop.Scale = 1.7
	tween(c.Pop, 0.28, { Scale = 1 }, Enum.EasingStyle.Back)
	play(sound)
end

function duelTap(b: any)
	b.kickCam = 1
	if b.myAura and b.myAura[1] and not reduced() then
		b.myAura[1]:Emit(3)
	end
	local knob = duelUI.Bar.Knob.Pop
	knob.Scale = 1.25
	tween(knob, 0.12, { Scale = 1 })
	local icon = duelUI.Hint.Icon.Pop
	icon.Scale = 0.82
	tween(icon, 0.14, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- the rival's body: hide for the fling's end, show again on his plate
function D.setRigVisible(b: any, rig: Model?, visible: boolean)
	if not rig then
		return
	end
	b.rigAlpha = b.rigAlpha or {}
	for _, p in rig:GetDescendants() do
		if p:IsA("BasePart") or p:IsA("Decal") then
			if b.rigAlpha[p] == nil then
				b.rigAlpha[p] = (p :: any).Transparency
			end
			(p :: any).Transparency = if visible then b.rigAlpha[p] else 1
		elseif p:IsA("BillboardGui") then
			p.Enabled = visible
		end
	end
end

-- The chess pieces play during the fight (Alex, Nov 8): about every 0.55 s whoever is pushing the bar
-- moves one of their pieces a legal-looking step (pawns forward, knights in an L, the rest one or two
-- squares), and a big swing captures one of the other side's pieces (it shrinks into the board).
-- Everything goes back to its start square when the duel ends.
D.MOVES = {
	Pawn = { { 0, 1 } },
	Knight = { { 1, 2 }, { -1, 2 }, { 2, 1 }, { -2, 1 }, { 1, -2 }, { -1, -2 }, { 2, -1 }, { -2, -1 } },
	Bishop = { { 1, 1 }, { -1, 1 }, { 2, 2 }, { -2, 2 }, { 1, -1 }, { -1, -1 } },
	Rook = { { 0, 1 }, { 0, 2 }, { 1, 0 }, { -1, 0 }, { 2, 0 }, { -2, 0 }, { 0, -1 } },
	Queen = { { 0, 1 }, { 0, 2 }, { 1, 1 }, { -1, 1 }, { 2, 2 }, { -2, 2 }, { 1, 0 }, { -1, 0 }, { 0, -1 } },
	King = { { 0, 1 }, { 1, 0 }, { -1, 0 }, { 1, 1 }, { -1, 1 }, { 0, -1 } },
}

function D.boardStart(b: any)
	local tbl = b.model and b.model:FindFirstChild("DuelBoard")
	local sqF = tbl and tbl:FindFirstChild("Squares")
	local pcF = tbl and tbl:FindFirstChild("Pieces")
	b.board = nil
	if not (sqF and pcF and b.axis) then
		return
	end
	local squares, step = {}, 0.44
	for _, q in sqF:GetChildren() do
		if q:IsA("BasePart") then
			table.insert(squares, q.Position)
			step = q.Size.X
		end
	end
	local pieces = {}
	for _, pc in pcF:GetChildren() do
		if pc:IsA("Model") then
			pc:SetAttribute("Hopping", nil)
			table.insert(pieces, { model = pc, home = pc:GetPivot(), at = pc:GetPivot().Position, side = pc:GetAttribute("Side"), alive = true })
		end
	end
	-- "forward" for you is along the board's grid toward the rival
	local ax = b.axis
	local fwd = if math.abs(ax.X) > math.abs(ax.Z) then Vector3.new(math.sign(ax.X), 0, 0) else Vector3.new(0, 0, math.sign(ax.Z))
	b.board = { squares = squares, pieces = pieces, step = step, fwd = fwd, right = Vector3.new(fwd.Z, 0, -fwd.X), clock = 0, last = 50 }
end

function D.onBoard(bd: any, pos: Vector3): boolean
	for _, q in bd.squares do
		if math.abs(q.X - pos.X) < bd.step * 0.3 and math.abs(q.Z - pos.Z) < bd.step * 0.3 then
			return true
		end
	end
	return false
end

function D.pieceAt(bd: any, pos: Vector3): any
	for _, p in bd.pieces do
		if p.alive and math.abs(p.at.X - pos.X) < bd.step * 0.3 and math.abs(p.at.Z - pos.Z) < bd.step * 0.3 then
			return p
		end
	end
	return nil
end

-- one move for `side`; with `capture` it first looks for one of the other side's pieces to take
function D.boardMove(bd: any, side: string, capture: boolean)
	local mine = {}
	for _, p in bd.pieces do
		if p.alive and p.side == side and not p.model:GetAttribute("Hopping") then
			table.insert(mine, p)
		end
	end
	if #mine == 0 then
		return
	end
	local dir = if side == "Player" then 1 else -1
	local best: any = nil
	for pass = (if capture then 1 else 2), 2 do
		for _ = 1, 12 do
			local p = mine[math.random(1, #mine)]
			local moves = D.MOVES[p.model.Name] or D.MOVES.King
			local m = moves[math.random(1, #moves)]
			local pawn = p.model.Name == "Pawn"
			if pawn and pass == 1 then
				m = { if math.random() < 0.5 then 1 else -1, 1 } -- pawns take on the diagonal
			end
			local target = p.at + bd.right * (m[1] * bd.step * dir) + bd.fwd * (m[2] * bd.step * dir)
			if D.onBoard(bd, target) then
				local occ = D.pieceAt(bd, target)
				if pass == 1 and occ and occ.side ~= side and occ.model.Name ~= "King" then
					best = { p = p, to = target, take = occ }
					break
				elseif pass == 2 and not occ then
					best = { p = p, to = target }
					break
				end
			end
		end
		if best then
			break
		end
	end
	if not best then
		return
	end
	local p, take = best.p, best.take
	local from, to = p.at, best.to
	p.at = to
	if take then
		take.alive = false
	end
	local pc = p.model
	pc:SetAttribute("Hopping", true)
	local rot = p.home.Rotation
	local high = if pc.Name == "Knight" then 0.55 else 0.22
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		if bd.ended or not pc.Parent then
			conn:Disconnect()
			return
		end
		local k = math.clamp((os.clock() - t0) / 0.24, 0, 1)
		local e = k * k * (3 - 2 * k)
		pc:PivotTo(CFrame.new(from:Lerp(to, e) + Vector3.new(0, math.sin(k * math.pi) * high, 0)) * rot)
		if k >= 1 then
			conn:Disconnect()
			pc:SetAttribute("Hopping", nil)
			if take and take.model.Parent then
				-- the taken piece shrinks into the board with a little gold burst
				local victim = take.model
				victim:SetAttribute("Hopping", true)
				if not reduced() then
					studBurst(CFrame.new(to + Vector3.new(0, 0.2, 0)), Color3.fromRGB(255, 214, 80), 5, "stud")
				end
				local s0 = os.clock()
				local c2: RBXScriptConnection
				c2 = RunService.RenderStepped:Connect(function()
					if bd.ended or not victim.Parent then
						c2:Disconnect()
						return
					end
					local q = math.clamp((os.clock() - s0) / 0.18, 0, 1)
					victim:ScaleTo(math.max(0.02, 1 - q))
					if q >= 1 then
						c2:Disconnect()
					end
				end)
			end
		end
	end)
end

-- called every frame of the fight: the side that pushed the bar since the last move moves next
function D.boardTick(b: any, dt: number)
	local bd = b.board
	if not bd or b.ended or os.clock() < (b.goAt or 0) then
		return
	end
	bd.clock += dt
	if bd.clock < 0.55 then
		return
	end
	bd.clock = 0
	local swing = b.display - bd.last
	bd.last = b.display
	local side = if swing >= 0 then "Player" else "Rival"
	D.boardMove(bd, side, math.abs(swing) > 4 and math.random() < 0.45)
end

function D.boardReset(b: any)
	local bd = b.board
	if not bd then
		return
	end
	bd.ended = true
	b.board = nil
	for _, p in bd.pieces do
		if p.model.Parent then
			if p.model:GetScale() ~= 1 then
				p.model:ScaleTo(1)
			end
			p.model:PivotTo(p.home)
			p.model:SetAttribute("Hopping", nil)
		end
	end
end

local function endBattleScene(b: any)
	D.boardReset(b)
	if b.camConn then
		b.camConn:Disconnect()
		b.camConn = nil
	end
	duelUI.Count.Visible = false
	if b.rival and b.rivalHome then
		b.rival:PivotTo(b.rivalHome)
	end
	if b.piece then
		b.piece:Destroy()
	end
	local npc = b.npc
	local me = player.Character
	D.dropAura(me)
	D.dropAura(npc)
	for _, rig in { me, npc } do
		setHold(rig, "Right", 0)
		setHold(rig, "Left", 0)
	end
	if npc and b.outcome ~= "win" then
		playAnim(npc, "Idle")
	end
	task.delay(if b.outcome then 1.6 else 0, function()
		releaseArms(me)
		releaseArms(npc)
	end)
	if npc and b.npcTap then
		b.npcTap = nil
		stopAnim(npc, "Tap")
		if b.outcome == "lose" then
			playAnim(npc, "Victory")
		end
		task.delay(1.8, function()
			stopAnim(npc, "Victory")
		end)
	elseif npc and b.outcome == "lose" then
		-- the rival celebrates: both arms up
		setHold(npc, "Left", 2.6)
		setHold(npc, "Right", 2.6)
		slap(npc, "Right")
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
	for _, pp in Stages:GetDescendants() do
		if pp:IsA("ProximityPrompt") and pp.Name == "BattlePrompt" then
			pp.Enabled = stageOpen(pp:GetAttribute("StageId") or "")
		end
	end
end

local function startBattleScene(b: any)
	local stageModel = Stages:FindFirstChild(b.stage)
	if not stageModel then
		return
	end
	b.model = stageModel
	b.rival = stageModel:FindFirstChild("Rival")
	b.rivalHome = b.rival and b.rival:GetPivot()
	local set = Config.Sets[S.Equipped] or Config.Sets.Wooden
	b.tile = stageModel:GetAttribute("TileSize") or 4
	b.npc = stageModel:FindFirstChild("RivalNPC")
	-- the badge anchor: an invisible piece above your head
	local plate = stageModel:FindFirstChild("PlayerSpot") :: BasePart
	b.piece = Models.Piece("Knight", set.color, b.tile * 0.24, plate.CFrame * CFrame.new(0, 4.5, 0), { trim = set.accent, material = setMaterial(S.Equipped) })
	b.piece.Name = "YourPiece"
	for _, part in b.piece:GetDescendants() do
		if part:IsA("BasePart") then
			part.Transparency = 1
		end
	end
	b.piece.Parent = fxFolder
	worldBadge = makeWorldBadge(b.piece.PrimaryPart)
	for _, pp in Stages:GetDescendants() do
		if pp:IsA("ProximityPrompt") and pp.Name == "BattlePrompt" then
			pp.Enabled = false
		end
	end
	local stageCfg = Config.Stages[b.stage]
	local opponent = stageCfg.opponent or {}
	-- the duel screen: names over the bar ends, the bar at the middle
	duelUI.Bar.You.Text = `@{player.Name}`
	duelUI.Bar.Rival.Text = opponent.name or stageCfg.name
	duelUI.Bar.Rival.TextColor3 = stageCfg.color
	duelUI.Bar.Fill.Size = UDim2.fromScale(0.5, 1)
	duelUI.Bar.Knob.Position = UDim2.fromScale(0.5, 0.5)
	duelUI.Hint.Text.Text = if isTouch then "Tap Fast!" else "Click Fast!"
	duelUI.Count.Visible = false
	setBattleHud(true)
	D.showTitle(`Stage {stageCfg.order or 1}`)
	-- both fighters hold their hands over the board; auras on
	for _, rig in { player.Character, b.npc } do
		setHold(rig, "Right", 1.05)
		setHold(rig, "Left", 1.05)
	end
	stopAnim(b.npc, "Idle")
	b.rivalSlaps = 0
	b.myAura = D.addAura(player.Character, Color3.fromRGB(255, 255, 255))
	b.rivalAura = D.addAura(b.npc, stageCfg.color:Lerp(Color3.new(1, 1, 1), 0.35))
	-- camera: over his shoulder, a sweep to the side view, then a slow push-in while you tap
	D.duelGeometry(b, stageModel)
	D.boardStart(b)
	camSaved = true
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = D.introCam(b, 0)
	b.camConn = RunService.RenderStepped:Connect(function(dt)
		if b.cinematic then
			return
		end
		local t = os.clock() - b.t0
		if t < D.DUEL_HOLD then
			camera.CFrame = D.introCam(b, 0)
		elseif t < D.DUEL_HOLD + D.DUEL_SWEEP then
			camera.CFrame = D.introCam(b, (t - D.DUEL_HOLD) / D.DUEL_SWEEP)
		else
			b.kickCam = math.max(0, (b.kickCam or 0) - dt * 6)
			local push = 0 -- build guide section 3 and vault note 28: the camera holds still while you tap
			camera.CFrame = D.sideCam(b, push)
		end
	end)
	-- 3, 2, 1, GO! (GO lands when the server starts counting taps)
	local intro = b.intro or 0
	if intro > 0 then
		for i, n in { "3", "2", "1" } do
			task.delay(math.max(0, intro - (4 - i) * D.DUEL_STEP), function()
				D.showCount(b, n, D.GOLD_COUNT, "Click")
			end)
		end
		task.delay(intro, function()
			D.showCount(b, "GO!", D.GREEN_GO, "Chime")
			task.delay(0.6, function()
				if duelUI.Count.Text == "GO!" then
					duelUI.Count.Visible = false
				end
			end)
		end)
	end
end

-- Glass shards where the rival breaks through his gate
function D.shatter(at: Vector3, dir: Vector3, color: Color3)
	-- 8 pooled shards (build guide section 3): made once, reused on every win, parked out of sight after
	if reduced() then
		return
	end
	D.shards = D.shards or {}
	for i = 1, 8 do
		local s = D.shards[i]
		if not s or not s.Parent then
			s = Instance.new("Part")
			s.Name = "Shard"
			s.Material = Enum.Material.Neon
			s.CanCollide, s.CanQuery, s.CanTouch, s.CastShadow = false, false, false, false
			s.Anchored = true
			s.Parent = fxFolder
			D.shards[i] = s
		end
		s.Size = Vector3.new(1.1, 1.1, 0.12) * (0.5 + math.random())
		s.CFrame = CFrame.new(at + Vector3.new(math.random() * 5 - 2.5, math.random() * 5 - 2.5, math.random() * 5 - 2.5))
			* CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		s.Color = color
		s.Transparency = 0.25
		s.Anchored = false
		s.AssemblyLinearVelocity = dir * (18 + math.random() * 14) + Vector3.new(math.random() * 16 - 8, math.random() * 14, math.random() * 16 - 8)
		s.AssemblyAngularVelocity = Vector3.new(math.random() * 20 - 10, math.random() * 20 - 10, math.random() * 20 - 10)
		tween(s, 1.1, { Transparency = 1 })
		task.delay(1.2, function()
			s.Anchored = true
			s.CFrame = CFrame.new(0, -400, 0)
		end)
	end
end

-- Win: the rival is flung through his gate (close shot as he flies past the camera), then the
-- camera comes back behind you, the HUD returns and the +Wins pop lands.
function D.winCinematic(b: any, p: any)
	b.cinematic = true
	duelUI.Enabled = false -- the bar goes as soon as you win
	duelUI.Count.Visible = false
	local stageCfg = Config.Stages[b.stage]
	local npc = b.npc :: Model?
	local gate = b.model and b.model:FindFirstChild("Gate")
	local barrier = gate and gate:FindFirstChild("Barrier") :: BasePart?
	local home = npc and npc:GetPivot() or CFrame.new(b.them)
	local start = home.Position
	local through = if barrier then Vector3.new(start.X, barrier.Position.Y - 2, barrier.Position.Z) else start + b.axis * 6
	local goal = through + b.axis * 30 + Vector3.new(0, 12, 0)
	local dur = 1.3
	if npc and b.npcTap then
		stopAnim(npc, "Tap")
		b.npcTap = nil
	end
	setHold(player.Character, "Right", 2.6)
	setHold(player.Character, "Left", 2.6)
	-- the shot: low and close, between the rival and his gate, so he flies at the camera and past it
	-- a wide shot from your side of the board, so his whole flight through the gate stays in frame
	local camPos = start - b.axis * 7 + b.side * 9 + Vector3.new(0, 4.5, 0)
	camera.CFrame = CFrame.lookAt(camPos, start:Lerp(through, 0.5) + Vector3.new(0, 2.2, 0))
	play("Capture")
	local t0 = os.clock()
	local smashed = false
	-- the impact when he breaks the gate (vault note 19 R2 and note 28): a 0.08 s hit-stop, then a +3 FOV
	-- kick that springs back and a small shake with no roll (trauma 0.35, shown squared). Skipped with Reduced Motion.
	local hit = { freezeEnd = 0, at = -1, trauma = 0, fov = camera.FieldOfView }
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		if now < hit.freezeEnd then
			return -- hit-stop: everything holds still for a moment
		end
		if hit.at > 0 then
			local k = now - hit.at
			camera.FieldOfView = hit.fov + 3 * math.exp(-k * 7) * math.cos(k * 11)
			hit.trauma = math.max(0, hit.trauma - dt * 1.2)
		end
		local a = math.clamp((now - t0) / dur, 0, 1)
		local e = 1 - (1 - a) ^ 1.4
		local pos = start:Lerp(goal, e) + Vector3.new(0, math.sin(a * math.pi) * 5, 0)
		local spin = CFrame.fromAxisAngle(b.side, -e * math.pi * 5)
		if npc and npc.Parent then
			npc:PivotTo(CFrame.new(pos) * spin * home.Rotation)
		end
		-- the camera stays put and follows him with its eyes
		local sh = hit.trauma * hit.trauma * math.rad(2.2)
		camera.CFrame = CFrame.lookAt(camPos, pos:Lerp(through, 0.45) + Vector3.new(0, 2, 0))
			* CFrame.Angles(sh * math.noise(now * 18, 1.5), sh * math.noise(now * 18, 7.5), 0)
		if not smashed and (pos - through):Dot(b.axis) >= 0 then
			smashed = true
			play("Win")
			if not reduced() then
				hit.freezeEnd = now + 0.08
				t0 += 0.08
				hit.at = now + 0.04
				hit.trauma = 0.35
			end
			if barrier and barrier.Transparency < 1 then
				D.shatter(through + Vector3.new(0, 2, 0), b.axis, barrier.Color)
				barrier:SetAttribute("Smashed", true)
				barrier.Transparency = 1
				barrier.CanCollide = false
			end
		end
		if a >= 1 then
			conn:Disconnect()
			camera.FieldOfView = hit.fov
			D.setRigVisible(b, npc, false)
			-- back behind you (0.45 s), then the normal camera, the HUD and the +Wins pop
			local r = root()
			if r then
				local look = (b.axis * Vector3.new(1, 0, 1)).Unit
				local behind = CFrame.lookAt(r.Position - look * 11 + Vector3.new(0, 5, 0), r.Position + look * 4 + Vector3.new(0, 1, 0))
				tween(camera, 0.45, { CFrame = behind }, Enum.EasingStyle.Quad)
			end
			task.delay(0.48, function()
				endBattleScene(b)
				refreshContext()
				local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
				if (p.reward or 0) > 0 and head then
					feel:Popup(head, `+{Format.Short(p.reward)} Wins`, "wins")
				end
				if stageCfg and stageCfg.boss then
					safe("boss moment", function()
						FeelKit.Moment(gui :: ScreenGui, "L", `YOU BEAT {string.upper((stageCfg.opponent or {}).name or stageCfg.name)}!`, { reduced = reduced, feel = feel })
					end)
				end
				-- the rival is back on his plate a moment later, ready for a rematch
				task.delay(2.2, function()
					if npc and npc.Parent then
						npc:PivotTo(home)
						D.setRigVisible(b, npc, true)
						studBurst(CFrame.new(start), Color3.fromRGB(235, 235, 235), 8, "stud")
						playAnim(npc, "Idle")
					end
				end)
			end)
		end
	end)
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
		resultFace.Line2.Text = "You keep your Elo and Wins"
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
			NeedPower = `Need {Format.Short(Config.Stages[stageId].power)} Elo. Tap for more Elo!`,
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
		t = 0, start = os.clock() + (d.intro or 0), ended = false, lastMove = 0,
		intro = d.intro or 0, t0 = os.clock(), goAt = os.clock() + (d.intro or 0),
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

-- Battle prompt over each rival (reference, Nov 8): walk up to him and press Battle (E, or tap it).
function D.stageOf(inst: Instance): Instance?
	local at: Instance? = inst
	while at and at.Parent ~= Stages do
		at = at.Parent
	end
	return at
end
function D.hookPrompt(stageModel: Instance?)
	local id = stageModel and stageModel.Name
	if not stageModel or not id or not Config.Stages[id] then
		return
	end
	local npc = stageModel:FindFirstChild("RivalNPC")
	local hrp = npc and npc:FindFirstChild("HumanoidRootPart")
	if not hrp or hrp:FindFirstChild("BattlePrompt") then
		return
	end
	local st = Config.Stages[id]
	local pp = Instance.new("ProximityPrompt")
	pp.Name = "BattlePrompt"
	pp.ActionText = "Battle"
	pp.ObjectText = (st.opponent or {}).name or st.name
	pp.KeyboardKeyCode = Enum.KeyCode.E
	pp.HoldDuration = 0
	pp.MaxActivationDistance = 12
	pp.RequiresLineOfSight = false
	pp:SetAttribute("StageId", id)
	pp.Enabled = stageOpen(id) and not battle
	pp.Parent = hrp
	pp.Triggered:Connect(function()
		if not battle then
			challenge(id)
		end
	end)
end
for _, m in Stages:GetChildren() do
	D.hookPrompt(m)
end
Stages.DescendantAdded:Connect(function(d)
	if d.Name == "RivalNPC" or d.Name == "HumanoidRootPart" then
		task.defer(D.hookPrompt, D.stageOf(d))
	end
end)
onState(function()
	for _, pp in Stages:GetDescendants() do
		if pp:IsA("ProximityPrompt") and pp.Name == "BattlePrompt" then
			pp.Enabled = stageOpen(pp:GetAttribute("StageId") or "") and not battle
		end
	end
end)

-- Lost a duel: a big tumbling arc back to the spawn, a dust puff on landing, then one short line.
local function flingHome(rivalName: string)
	local r, h = root(), humanoid()
	local spawnPart = map:FindFirstChild("Spawn") :: BasePart?
	if not r or not h or not spawnPart then
		return
	end
	-- wait for the duel hold to let go (the server anchors you during the fight)
	local waited = 0
	while r.Anchored and waited < 1.5 do
		waited += task.wait()
	end
	local start = r.Position
	local look = spawnPart.CFrame.LookVector
	local goal = spawnPart.Position + look * 4 + Vector3.new(0, h.HipHeight + r.Size.Y / 2 + 0.3, 0)
	local dist = (goal - start).Magnitude
	local height = math.clamp(dist * 0.35, 14, 40)
	local dur = math.clamp(0.9 + dist / 120, 1.1, 1.8)
	local spinAxis = (goal - start).Unit:Cross(Vector3.yAxis)
	if spinAxis.Magnitude < 0.1 then
		spinAxis = Vector3.xAxis
	end
	spinAxis = spinAxis.Unit
	h.PlatformStand = true
	play("Lose")
	local t0 = os.clock()
	local done = false
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		if not r.Parent then
			conn:Disconnect()
			return
		end
		local a = math.clamp((os.clock() - t0) / dur, 0, 1)
		local pos = start:Lerp(goal, a) + Vector3.new(0, math.sin(a * math.pi) * height, 0)
		-- two tumbles in the air, upright again for the landing
		local spin = if a < 0.85 then CFrame.fromAxisAngle(spinAxis, -a / 0.85 * math.pi * 4) else CFrame.identity
		r.CFrame = CFrame.lookAt(pos, pos + Vector3.new(look.X, 0, look.Z)) * spin
		r.AssemblyLinearVelocity = Vector3.zero
		r.AssemblyAngularVelocity = Vector3.zero
		if a >= 1 and not done then
			done = true
			conn:Disconnect()
			r.CFrame = CFrame.lookAt(goal, goal + Vector3.new(look.X, 0, look.Z))
			h.PlatformStand = false
			h:ChangeState(Enum.HumanoidStateType.GettingUp)
			studBurst(CFrame.new(goal - Vector3.new(0, h.HipHeight + r.Size.Y / 2, 0)), Color3.fromRGB(235, 235, 235), 10, "stud")
			message(`{rivalName} flung you back! Train more Elo and try again`, Color3.fromRGB(255, 210, 90))
		end
	end)
end

Net.On("BattleEnd", function(p: any)
	local b = battle
	if not b or p.id ~= b.id then
		return
	end
	b.ended = true
	b.outcome = p.outcome
	battle = nil
	if p.outcome == "win" then
		winsShownUntil = os.clock() + 5 -- the Victory card shows the Wins; no second popup over your head
	end
	resultLockUntil = os.clock() + 2.5
	task.delay(0.2, function()
		safe("guide", refreshGuide) -- the guide line comes back once the duel is over
	end)
	if p.outcome == "cancelled" then
		endBattleScene(b)
		refreshContext()
		return
	end
	b.serverMeter = p.meter
	local stageCfg = Config.Stages[b.stage]
	if p.outcome == "win" then
		-- Nov 8 (reference): no Victory card. The rival is flung through his gate, the camera comes
		-- back behind you, then the +Wins pop. The guide line carries the next step.
		for _, key in p.badges or {} do
			showBadge(key)
		end
		safe("win fling", function()
			D.winCinematic(b, p)
		end)
		log(`battle {p.id}: win +{p.reward or 0} wins`)
		return
	end
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
		if p.outcome == "lose" then
			-- Alex (Nov 8): no Defeat card. Like the reference, the rival flings you back to the start.
			local rivalName = (stageCfg and ((stageCfg.opponent or {}).name or stageCfg.name)) or "Your rival"
			safe("fling home", function()
				flingHome(rivalName)
			end)
		else
			showResult(p)
		end
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
	-- a finished duel is sent as a missing key; without this the old duel sticks and hides the guide
	S.battle = snap.battle
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
-- Auto Wins (top bar switch, clip 2 of Nov 8): walk the lane to the next rival.
-- Strong enough: fight it (auto taps, same 6/s cap as a hand). Too weak: walk to the
-- newest beaten stage's trophy (its Return pad pays Wins and sends you to the hub), repeat.
---------------------------------------------------------------------------
local function lastCleared(): string?
	local best = nil
	for _, id in Config.StageOrder do
		if S.Cleared and S.Cleared[id] then
			best = id
		end
	end
	return best
end
local function trophyWins(id: string): number
	return math.floor(Config.Stages[id].reward * Config.WinsMult(S.Promotions or 0, S.Passes))
end
-- Return pads of beaten stages show their trophy: "Return" over "+N Wins" (the reference's pads)
local function refreshTrophies()
	for _, m in Stages:GetChildren() do
		local ret = Config.Stages[m.Name] and m:FindFirstChild("Return")
		local bb = ret and ret:FindFirstChild("ReturnLabel") :: BillboardGui?
		local line1 = bb and bb:FindFirstChild("Line1") :: TextLabel?
		if bb and line1 then
			local line2 = bb:FindFirstChild("Line2") :: TextLabel?
			if not line2 then
				local l2 = line1:Clone()
				l2.Name = "Line2"
				l2.LayoutOrder = line1.LayoutOrder + 1
				l2.TextColor3 = Hud.Colors.gold
				l2.Parent = bb
				line2 = l2
			end
			local on = S.Cleared and S.Cleared[m.Name] == true
			;(line2 :: TextLabel).Visible = on
			if on then
				(line2 :: TextLabel).Text = `+{trophyWins(m.Name)} Wins`
			end
			line1.Size = if on then UDim2.fromScale(1, 0.5) else UDim2.fromScale(1, 1);
			(line2 :: TextLabel).Size = UDim2.fromScale(1, 0.5)
			bb.Size = if on then UDim2.fromScale(5, 3) else UDim2.fromScale(5, 1.5)
		end
	end
end
-- Treadmill signs follow the real unlock state: "Clear Stage N" until the server confirms it, then "OPEN".
local function refreshStationSigns()
	for _, m in Stations:GetChildren() do
		local st = Config.Stations[m.Name]
		local anchor = m:FindFirstChild("LabelAnchor")
		local lab = anchor and anchor:FindFirstChild("Label")
		local l1 = lab and lab:FindFirstChild("Line1") :: TextLabel?
		local l2 = lab and lab:FindFirstChild("Line2") :: TextLabel?
		if st and l1 and l2 then
			local open, whyNot = stationOpen(m.Name)
			-- two stable lines: the machine's name, then the Elo it pays each second while you stand on it.
			-- A locked machine also shows the rebirth pill above it (RebirthNeed, built in Studio).
			local perSec = Format.Short(Config.Gain(m.Name) * Config.PowerMult(S.Promotions or 0, S.Passes) / Config.TreadmillTick)
			l1.Text = st.name or m.Name
			if open then
				l2.Text = `+{perSec} Elo/sec · ` .. (if st.unlock then "OPEN" else "FREE")
				l2.TextColor3 = Color3.fromRGB(120, 255, 120)
			else
				local status = if st.built then "LOCKED" else (whyNot or "Coming soon")
				l2.Text = `+{perSec} Elo/sec · {status}`
				l2.TextColor3 = Color3.fromRGB(255, 210, 90)
			end
			local need = anchor and anchor:FindFirstChild("RebirthNeed") :: BillboardGui?
			if need then
				need.Enabled = st.built and not open
			end
		end
	end
end
onState(function()
	safe("stationSigns", refreshStationSigns)
end)
-- the map streams in: signs that arrive after the last State get their text too
local signsQueued = false
Stations.DescendantAdded:Connect(function(d)
	if signsQueued or not (d.Name == "Label" or d.Name == "Line2" or d.Name == "RebirthNeed") then
		return
	end
	signsQueued = true
	task.delay(0.2, function()
		signsQueued = false
		safe("stationSigns", refreshStationSigns)
	end)
end)
onState(function()
	safe("trophies", refreshTrophies)
end)

local autoState = { tapAt = 0, tickAt = 0, resultAt = nil :: number?, challengeAt = 0, sayAt = 0, was = false }
local function autoSay(t: string)
	if os.clock() - autoState.sayAt > 5 then
		autoState.sayAt = os.clock()
		message(t, Color3.fromRGB(255, 210, 90))
	end
end
-- One MoveTo step towards a spot; true once there. Off the lane (hub, treadmills) it steps
-- onto the lane's centre line first, so it never cuts across the treadmill rows, and it keeps
-- to the centre line until level with the target, so it never clips an earlier Return pad.
local function walkTowards(target: Vector3, arrive: number): boolean
	local r, h = root(), humanoid()
	if not r or not h or h.Health <= 0 or h.WalkSpeed <= 0 then
		return false
	end
	local here = r.Position
	local flat = Vector3.new(target.X, here.Y, target.Z)
	if (flat - here).Magnitude <= arrive then
		return true
	end
	local dest = flat
	if here.Z > -44 and math.abs(here.X) > 8 then
		dest = Vector3.new(0, here.Y, math.clamp(here.Z, -30, 0))
	elseif math.abs(here.Z - target.Z) > 6 and math.abs(target.X) > 4 then
		dest = Vector3.new(0, here.Y, target.Z)
	end
	h:MoveTo(dest)
	return false
end
local function stepAutoWins()
	local nxt = nextStage()
	local now = os.clock()
	if nxt and (S.Power or 0) >= Config.Stages[nxt].power then
		local zone = Stages:FindFirstChild(nxt) and Stages[nxt]:FindFirstChild("Zone") :: BasePart?
		if zone and walkTowards(zone.Position, 3) and now - autoState.challengeAt > 2.5 then
			autoState.challengeAt = now
			task.spawn(challenge, nxt)
		end
		return
	end
	local farm = lastCleared()
	if farm then
		local ret = Stages:FindFirstChild(farm) and Stages[farm]:FindFirstChild("Return") :: BasePart?
		if ret then
			walkTowards(ret.Position, 0.5) -- the Return pad check above collects and sends you home
		end
		if nxt then
			autoSay(`Auto Wins: collecting +{trophyWins(farm)} Wins. {Config.Stages[nxt].name} needs {Format.Short and Format.Short(Config.Stages[nxt].power) or Config.Stages[nxt].power} Elo`)
		end
	elseif nxt then
		local zone = Stages:FindFirstChild(nxt) and Stages[nxt]:FindFirstChild("Zone") :: BasePart?
		if zone then
			walkTowards(zone.Position + Vector3.new(0, 0, 14), 3)
		end
		autoSay(`Auto Wins: train to {Config.Stages[nxt].power} Elo to fight {Config.Stages[nxt].name}`)
	end
end
RunService.Heartbeat:Connect(function()
	local on = player:GetAttribute("AutoWins") == true
	if on ~= autoState.was then
		autoState.was = on
		message(if on then "Auto Wins ON" else "Auto Wins OFF", if on then Hud.Colors.gold else nil)
		local r, h = root(), humanoid()
		if not on and r and h then
			h:MoveTo(r.Position) -- stop where you are
		end
	end
	if not on then
		return
	end
	local now = os.clock()
	if battle and not battle.ended then
		if now - autoState.tapAt >= 1 / 6 then
			autoState.tapAt = now
			safe("auto tap", doAction)
		end
		return
	end
	if now - autoState.tickAt < 0.25 then
		return
	end
	autoState.tickAt = now
	if openPanel == "Result" then
		autoState.resultAt = autoState.resultAt or now
		if now - (autoState.resultAt :: number) > 1.4 then
			autoState.resultAt = nil
			closePanels()
		end
		return
	end
	autoState.resultAt = nil
	if battle or not S.Cleared then
		return
	end
	safe("auto wins", stepAutoWins)
end)

---------------------------------------------------------------------------
-- Frame loop: context, belts, run anim, meter, guide arrows, gallery motion
---------------------------------------------------------------------------
local lastContext = 0
local lastReturn = 0
local lastDeck: string? = nil
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
					task.spawn(function()
						winsShownUntil = os.clock() + 2
						local res = Net.Request("Return")
						if res.ok and res.data and (res.data.trophy or 0) > 0 then
							winsShownUntil = os.clock() + 1
							toast(`Return bonus +{res.data.trophy} Wins`, Hud.Colors.gold)
							play("Gain")
						end
					end)
				end
			end
		end
	end

	-- training: run animation and belt speed for me and for other players.
	-- Like the reference, standing on an open treadmill's deck starts you running right away
	-- (no TRAIN press); each tap anywhere on the screen then gives Elo.
	local deckId = standingOnDeck()
	if deckId ~= lastDeck then
		lastDeck = deckId
		if deckId then
			alignOnDeck(deckId)
		end
	end
	local myTraining = ctx.kind == "station" and (now < trainingUntil or deckId == ctx.id)
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
		duelUI.Bar.Fill.Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1)
		duelUI.Bar.Knob.Position = UDim2.fromScale(math.clamp(frac, 0, 1), 0.5)
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
			b.rivalSlaps = (b.rivalSlaps or 0) + dt * math.clamp(Config.Pressure(b.fight, elapsed) / b.fight.perTap * 3, 3, 9)
			if b.rivalSlaps >= 1 then
				b.rivalSlaps -= 1
				b.rivalHand = if b.rivalHand == "Left" then "Right" else "Left"
				slap(b.npc, b.rivalHand)
				pressButton(b, "ClockButtonB")
				if b.rivalAura and b.rivalAura[1] and not reduced() then
					b.rivalAura[1]:Emit(2)
				end
			end
		end
		D.boardTick(b, dt)
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
				local pos = from + dir * d + Vector3.new(0, 0.3 + math.sin(now * 3 + i) * 0.08, 0)
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
		if not entry.model.Parent then
			continue -- streamed out; set up again when it streams back in
		end
		local bob = math.sin(now * 1.6 + entry.phase) * 0.35
		local turn = math.sin(now * 0.5 + entry.phase) * 0.35
		entry.model:PivotTo(entry.base * CFrame.new(0, bob + 0.6, 0) * CFrame.Angles(0, turn, 0))
		if entry.orbit then
			for i, bead in entry.orbit do
				local a = now * 1.4 + i * (math.pi * 2 / #entry.orbit)
				bead.CFrame = CFrame.new(entry.core + Vector3.new(math.cos(a) * 3.2, math.sin(a * 2) * 0.6 + bob + 0.6, math.sin(a) * 3.2))
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
