--!strict
-- The client side of the story's crew stages and missions (Piece 3). Renders what MissionState says; every step is
-- decided by the server (MissionService / StoryCrew). Uses PlayerGui.MTL_Mission (from StarterGui, reskinnable).
--   meet       the crew waiting at the meet spot by a car with hazard lights (local actors, visible from far off)
--   state      tracker (top right), local props (getaway car, crew, mask box, till), highlight on the target,
--              hold prompt (E / X / press-and-hold the prompt), aim step, alarm + clean-getaway timer
--   bark       a crew line at the bottom of the screen
--   progress   the aim meter when GunService drives the aim step
--   payout     the payout card (counts up), then the offer card (2x Money pass / boost, "Maybe later")
--   MissionController.state() -> last "state" payload    MissionController.Changed: Signal(payload)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local MarketplaceService = game:GetService("MarketplaceService")

local Net = require(ReplicatedStorage.MTL.Net)
local Signal = require(ReplicatedStorage.MTL.Signal)
local Theme = require(ReplicatedStorage.MTL.UI.Theme)
local Sfx = require(ReplicatedStorage.MTL.UI.Sfx)
local Motion = require(ReplicatedStorage.MTL.UI.Motion)
local Format = require(ReplicatedStorage.MTL.Format)
local Story = require(ReplicatedStorage.MTL.Config.Story)
local Missions = require(ReplicatedStorage.MTL.Config.Missions)
local MissionRules = require(ReplicatedStorage.MTL.Rules.MissionRules)
local Build = require(ReplicatedStorage.MTL.UI.Build.Mission)
local UIState = require(script.Parent.UIState)
local Actors = require(script.Parent.Actors)
local Cutscene = require(script.Parent.CutsceneController)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local C = Theme.Colors
local M = Theme.Mission

local MissionController = {}
MissionController.Changed = Signal.new()

local gui: any
local current: any = nil -- last "state" payload
local holding = false
local holdStart = 0
local holdSent = false
local aiming = false
local aimStart: number? = nil
local aimSent = false
local serverProgress = 0
local alarmSound: Sound? = nil
local barkQueue: { { who: string, text: string } } = {}
local barkBusy = false
local payoutMsg: any = nil

local HOLD_KEYS = { [Enum.KeyCode.E] = true, [Enum.KeyCode.ButtonX] = true }
local AIM_INPUTS = { [Enum.UserInputType.MouseButton2] = true }
local AIM_KEYS = { [Enum.KeyCode.ButtonL2] = true }

local function sound(key: string, volume: number?)
	local id = (M.Sounds :: any)[key]
	if type(id) ~= "string" or id == "" or id == "rbxassetid://0" then
		return
	end
	Sfx.playId(id, { volume = volume or 0.5 })
end

local function action(t: string, payload: { [string]: any }?)
	local p = payload or {}
	p.type = t
	Net.get("MissionAction"):FireServer(p)
end

local function root(): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function getGui()
	local pg = player:WaitForChild("PlayerGui")
	local existing = pg:FindFirstChild("MTL_Mission")
	if existing then
		return existing
	end
	local built = Build.build()
	built.Parent = pg
	return built
end

---------------------------------------------------------------- local scenes (meet + mission props)

type Scene = { folder: Folder, actors: { [string]: { actor: Actors.Actor, cf: CFrame, pose: string } }, props: { [string]: Model } }

local function newScene(name: string): Scene
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = Actors.folder()
	return { folder = f, actors = {}, props = {} }
end

local function clearScene(s: Scene?)
	if s then
		s.folder:Destroy()
	end
end

local function addActor(s: Scene, name: string, worldPos: Vector3, facePos: Vector3, pose: string)
	if s.actors[name] then
		return
	end
	local a = Actors.spawn(name, s.folder)
	if not a then
		return
	end
	local y = Actors.floor(worldPos)
	local p = Vector3.new(worldPos.X, y, worldPos.Z)
	local f = Vector3.new(facePos.X, y, facePos.Z)
	local cf = if (f - p).Magnitude > 0.1 then CFrame.lookAt(p, f) else CFrame.new(p)
	s.actors[name] = { actor = a, cf = cf, pose = pose }
	Actors.place(a, cf)
end

local function renderScene(s: Scene?)
	if not s then
		return
	end
	local now = os.clock()
	local r = root()
	for _, e in s.actors do
		local state: any = { pose = e.pose, poseT0 = -10 }
		-- glance at the player when they're close
		if r and (r.Position - e.cf.Position).Magnitude < 30 then
			local rel = e.cf:PointToObjectSpace(r.Position)
			state.lookYaw = math.atan2(-rel.X, -rel.Z)
		end
		Actors.render(e.actor, state, now)
	end
end

---------------------------------------------------------------- the meet

local meet: { cframe: CFrame, label: string }? = nil
local meetScene: Scene? = nil

local function buildMeet()
	if not meet or meetScene then
		return
	end
	local cf = meet.cframe
	local L = Missions.Meet.Layout
	local s = newScene("Meet")
	meetScene = s -- claimed before anything yields (rigs may take a moment), so it's built once
	local car = Actors.prop("CrewCar", { parent = s.folder, hazards = true })
	if car then
		local world = cf * L.Car
		local y = Actors.floor(world.Position, { car })
		car:PivotTo(world + Vector3.new(0, y - world.Position.Y, 0))
		s.props.Car = car
	end
	for _, name in { "Dre", "Smoke", "Nina" } do
		local d = (L :: any)[name]
		if meetScene ~= s then
			return -- cleared while building
		end
		addActor(s, name, cf:PointToWorldSpace(d.at), cf:PointToWorldSpace(d.face), d.pose or (if name == "Dre" then "Cross" else "None"))
	end
end

local function clearMeet()
	clearScene(meetScene)
	meetScene = nil
end

---------------------------------------------------------------- mission props

local missionScene: Scene? = nil
local highlight: Highlight? = nil
local tillLight: PointLight? = nil

local function setHighlight(target: Instance?)
	if highlight and highlight.Adornee == target then
		return
	end
	if highlight then
		highlight:Destroy()
		highlight = nil
	end
	if target then
		-- the house style for every cue (UI/Guide): gold outline, gentle shared pulse, not drawn through walls
		local h = require(ReplicatedStorage.MTL.UI.Guide).outline(target, Actors.folder())
		h.Name = "MTL_MissionHighlight"
		highlight = h
	end
end

local function clearMission()
	setHighlight(nil)
	clearScene(missionScene)
	missionScene = nil
	tillLight = nil
end

local syncProps: (any) -> () -- defined below (buildMission refreshes props once the crew rigs arrive)

local function buildMission(state: any)
	if missionScene then
		return
	end
	local s = newScene("Mission")
	missionScene = s -- claimed before anything yields
	local carCf: CFrame = state.car
	-- the car point can sit above the ground (station parts float): drop everything at the car onto the floor
	carCf = carCf + Vector3.new(0, Actors.floor(carCf.Position) - carCf.Position.Y, 0)
	local car = Actors.prop("CrewCar", { parent = s.folder, hazards = false })
	if car then
		car:PivotTo(carCf)
		s.props.Car = car
	end
	-- mask box in the trunk
	local box = Actors.prop("Mask", { parent = s.folder })
	if box then
		local at = carCf * CFrame.new(0, 2.3, 6.2)
		box:PivotTo(at)
		s.props.Mask = box
	end
	-- crew at the car: Nina by the trunk, Dre leaning on the side (Smoke is "in the driver's seat").
	-- Rigs can take a moment to arrive, so they're added in the background.
	task.spawn(function()
		addActor(s, "Nina", carCf:PointToWorldSpace(Vector3.new(3.2, 0, 8.5)), carCf:PointToWorldSpace(Vector3.new(0, 0, 12)), "None")
		addActor(s, "Dre", carCf:PointToWorldSpace(Vector3.new(-4.6, 0, 2)), carCf:PointToWorldSpace(Vector3.new(-8, 0, 8)), "Cross")
		if missionScene == s and current then
			syncProps(current)
		end
	end)
	-- the till at the register: an open cash drawer that glows during the grab
	local reg: Vector3 = state.register
	local y = Actors.floor(reg)
	local till = Instance.new("Model")
	till.Name = "Till"
	local drawer = Actors.part({ Name = "Drawer", Size = Vector3.new(1.6, 0.35, 1.2), Color = Color3.fromRGB(40, 42, 50), CFrame = CFrame.new(reg.X, y + 3.4, reg.Z), Parent = till })
	-- the cash: banded stacks of bills (ReplicatedStorage.MTL_Actors.CashStack) when the mesh is there
	local lib = ReplicatedStorage:FindFirstChild("MTL_Actors")
	local stack = lib and lib:FindFirstChild("CashStack")
	if stack and stack:IsA("BasePart") then
		local cash = stack:Clone()
		cash.Name = "Cash"
		cash.Anchored = true
		cash.CFrame = CFrame.new(reg.X, y + 3.55 + cash.Size.Y / 2, reg.Z)
		cash.Transparency = 1
		cash.Parent = till
	else
		Actors.part({ Name = "Cash", Size = Vector3.new(1.3, 0.2, 0.9), Color = Color3.fromRGB(90, 170, 100), Material = Enum.Material.Neon, CFrame = CFrame.new(reg.X, y + 3.62, reg.Z), Transparency = 1, Parent = till })
	end
	till.PrimaryPart = drawer
	till.Parent = s.folder
	local light = Instance.new("PointLight")
	light.Color = M.Alarm
	light.Range = 26
	light.Brightness = 0
	light.Parent = drawer
	tillLight = light
	s.props.Till = till
end

syncProps = function(state: any)
	if not missionScene then
		return
	end
	local s = missionScene
	local idx = state.index or 1
	local stepId = state.step and state.step.id
	-- crew climbs in once you're inside the store
	if idx > (MissionRules.stepIndex(Missions.FirstMission, "Enter") or 2) then
		for _, e in s.actors do
			Actors.setHidden(e.actor, true)
		end
	end
	if s.props.Mask then
		s.props.Mask.Parent = if idx > 1 then nil else s.folder
	end
	if s.props.Car then
		Actors.hazards(s.props.Car, state.alarm == true)
	end
	local till = s.props.Till
	if till and till:FindFirstChild("Cash") then
		(till :: any).Cash.Transparency = if stepId == "Grab" then 0 else 1
	end
	-- outline the thing to go to
	local target: Instance? = nil
	if stepId == "Mask" then
		target = s.props.Mask or s.props.Car
	elseif stepId == "Threaten" then
		target = workspace:FindFirstChild("MTL_Clerk")
	elseif stepId == "Grab" then
		target = till
	elseif stepId == "Escape" then
		target = s.props.Car
	end
	setHighlight(target)
end

---------------------------------------------------------------- tracker + prompt + meter

local function renderTracker(state: any)
	local tr = gui.Tracker
	tr.Body.MissionName.Text = state.title or ""
	local steps = tr.Body.Steps
	for _, c in steps:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	for i, s in state.steps or {} do
		local row = Build.stepRow(s.text, if s.done then "done" elseif s.current then "current" else "todo")
		row.LayoutOrder = i
		row.Parent = steps
	end
	if not tr.Visible then
		tr.Visible = true
		tr.Position = UDim2.new(1, 40, 0, 120)
		Motion.tween(tr, Motion.Spring, { Position = UDim2.new(1, -16, 0, 120) })
	end
end

local function keyGlyph(): string
	if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return "X"
	elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "✋"
	end
	return "E"
end

local function resetHold()
	holding = false
	holdSent = false
	gui.Prompt.Bar.Fill.Size = UDim2.fromScale(0, 1)
end

local function inRange(state: any, extra: number?): boolean
	local r = root()
	local st = state and state.step
	if not r or not st or not st.pos then
		return false
	end
	local d = Vector2.new(r.Position.X - st.pos.X, r.Position.Z - st.pos.Z).Magnitude
	return d <= (st.radius or 6) + (extra or 0)
end

local function beginHold()
	local st = current and current.step
	if not st or st.kind ~= "hold" or not inRange(current) then
		return
	end
	holding = true
	holdStart = os.clock()
	holdSent = false
	action("begin", { step = st.id })
	Motion.tween(gui.Prompt.Pop, Motion.Fast, { Scale = 0.96 })
end

local function endHold()
	if holding then
		resetHold()
		Motion.tween(gui.Prompt.Pop, Motion.Fast, { Scale = 1 })
	end
end

-- built-in aim (only when the Guns piece isn't driving the aim step)
local savedOffset = Vector3.zero
local function setAimCam(on: boolean)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	if on then
		savedOffset = hum.CameraOffset
		hum.CameraOffset = Vector3.new(1.75, 0.4, 0)
		hum.AutoRotate = false
		Motion.tween(camera, Motion.Fast, { FieldOfView = 55 })
	else
		hum.CameraOffset = savedOffset
		hum.AutoRotate = true
		Motion.tween(camera, Motion.Fast, { FieldOfView = 70 })
	end
end

local function startAim()
	local st = current and current.step
	if not st or st.kind ~= "aim" or not current.aimFallback or aiming then
		return
	end
	aiming = true
	aimStart = nil
	aimSent = false
	setAimCam(true)
end

local function stopAim()
	if not aiming then
		return
	end
	aiming = false
	aimStart = nil
	setAimCam(false)
	gui.Meter.Bar.Fill.Size = UDim2.fromScale(0, 1)
end

local function facingClerk(): boolean
	local r = root()
	if not r or not current or not current.clerk then
		return false
	end
	local look = r.CFrame.LookVector
	local def = Missions.FirstMission
	return MissionRules.facingOk(r.Position.X, r.Position.Z, look.X, look.Z, current.clerk.X, current.clerk.Z, def.AimDot, def.AimRange)
end

---------------------------------------------------------------- barks

local function runBarks()
	if barkBusy then
		return
	end
	barkBusy = true
	while #barkQueue > 0 do
		local b = table.remove(barkQueue, 1) :: any
		local frame = gui.Bark
		local contact = (Story.Contacts :: any)[b.who]
		frame.Speaker.Text = string.upper(if contact then contact.Name else b.who)
		frame.Speaker.TextColor3 = (Theme.Cutscene.Speakers :: any)[b.who] or M.Accent
		frame.Line.Text = b.text
		frame.Line.MaxVisibleGraphemes = 0
		frame.Visible = true
		local n = utf8.len(b.text) or #b.text
		local t0 = os.clock()
		while os.clock() - t0 < n / 45 do
			frame.Line.MaxVisibleGraphemes = math.floor((os.clock() - t0) * 45)
			task.wait()
		end
		frame.Line.MaxVisibleGraphemes = -1
		task.wait(math.clamp(1.4 + n / 22, 2, 4.5))
		frame.Visible = false
		task.wait(0.15)
	end
	barkBusy = false
end

local function bark(who: string, text: string)
	table.insert(barkQueue, { who = who, text = text })
	task.spawn(runBarks)
end

---------------------------------------------------------------- alarm

local function setAlarm(on: boolean)
	gui.Alarm.Visible = on
	if on and not alarmSound then
		local id = M.Sounds.Alarm
		if id ~= "" and id ~= "rbxassetid://0" then
			local s = Instance.new("Sound")
			s.Name = "MTL_Alarm"
			s.SoundId = id
			s.Looped = true
			s.Volume = 0.25
			s.PlaybackSpeed = 1
			s.Parent = gui
			s:Play()
			alarmSound = s
		end
	elseif not on and alarmSound then
		alarmSound:Destroy()
		alarmSound = nil
	end
end

---------------------------------------------------------------- state

local alarmStartedLocal: number? = nil

local function onState(state: any)
	local first = current == nil or current.mission ~= state.mission
	local stepChanged = current == nil or current.index ~= state.index
	current = state
	if first then
		Cutscene.releaseBlack(0.8)
		clearMeet()
	end
	buildMission(state)
	renderTracker(state)
	syncProps(state)
	if stepChanged then
		resetHold()
		stopAim()
		serverProgress = 0
		gui.Meter.Bar.Fill.Size = UDim2.fromScale(0, 1)
		if not first then
			sound("Step", 0.35)
		end
	end
	if state.alarm then
		if not alarmStartedLocal then
			alarmStartedLocal = os.clock() - (state.alarmFor or 0)
		end
	else
		alarmStartedLocal = nil
	end
	setAlarm(state.alarm == true)
	gui.Prompt.Key.Text = keyGlyph()
	gui.Prompt.Verb.Text = state.step.verb or "Hold"
	gui.Meter.Label.Text = if state.aimFallback
		then (if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then "HOLD AIM ON THE CLERK" else "HOLD RIGHT-CLICK ON THE CLERK")
		else "AIM AT THE CLERK"
	MissionController.Changed:Fire(state)
end

local function onClear()
	current = nil
	resetHold()
	stopAim()
	setAlarm(false)
	alarmStartedLocal = nil
	clearMission()
	gui.Prompt.Visible = false
	gui.Meter.Visible = false
	gui.AimButton.Visible = false
	if gui.Tracker.Visible then
		local tr = gui.Tracker
		Motion.tween(tr, Motion.Normal, { Position = UDim2.new(1, 40, 0, 120) }).Completed:Wait()
		if not current then
			tr.Visible = false
		end
	end
	MissionController.Changed:Fire(nil)
end

---------------------------------------------------------------- payout + offer

local priceCache: { [string]: string } = {}

local function priceText(item: any, done: (string) -> ())
	if item.owned then
		done("OWNED")
		return
	end
	if not item.id or item.id == 0 then
		done("Coming soon")
		return
	end
	local key = item.kind .. ":" .. item.id
	if priceCache[key] then
		done(priceCache[key])
		return
	end
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(item.id, if item.kind == "pass" then Enum.InfoType.GamePass else Enum.InfoType.Product)
		end)
		local text = if ok and info and info.PriceInRobux then ("R$ " .. tostring(info.PriceInRobux)) else "Buy"
		priceCache[key] = text
		done(text)
	end)
end

local function hideFull(frame: Frame)
	local card = frame:FindFirstChild("Card") :: any
	if card and card:FindFirstChild("Pop") then
		Motion.tween(card.Pop, Motion.Fast, { Scale = 0.9 })
	end
	task.delay(0.12, function()
		frame.Visible = false
	end)
end

local function showFull(frame: Frame)
	frame.Visible = true
	local card = frame:FindFirstChild("Card") :: any
	if card and card:FindFirstChild("Pop") then
		card.Pop.Scale = 0.85
		Motion.tween(card.Pop, Motion.Spring, { Scale = 1 })
	end
end

local function renderOffer(msg: any)
	local card = gui.Offer.Card
	local take = (msg.take or 0) + (msg.bonus or 0)
	card.Sub.Text = string.format("This job paid %s. With 2x Money it pays %s, and so does every job after it.", Format.cash(take), Format.cash(msg.doubled or take * 2))
	local tiles = card.Tiles
	for _, c in tiles:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	for i, item in msg.offer or {} do
		local tile = Build.offerTile(item.title, item.sub, if item.kind == "pass" then M.Icons.Pass else M.Icons.Boost)
		tile.LayoutOrder = i
		tile.Parent = tiles
		local buy = tile.Buy
		buy.Text = "..."
		priceText(item, function(text)
			if buy.Parent then
				buy.Text = text
			end
		end)
		if item.owned then
			buy.AutoButtonColor = false
			buy.BackgroundTransparency = 0.6
		else
			buy.Activated:Connect(function()
				action("buy", { item = item.item })
			end)
		end
	end
end

local function closeOffer()
	hideFull(gui.Offer)
	UIState.pop("Payout")
	action("closeOffer")
	payoutMsg = nil
end

local function showOffer(msg: any)
	local anyToBuy = false
	for _, it in msg.offer or {} do
		if not it.owned then
			anyToBuy = true
		end
	end
	if not anyToBuy then
		closeOffer()
		return
	end
	renderOffer(msg)
	showFull(gui.Offer)
end

local function showPayout(msg: any)
	payoutMsg = msg
	if gui.Offer.Visible then
		renderOffer(msg) -- a pass was bought: refresh the tiles (OWNED)
		return
	end
	Cutscene.releaseBlack(0.9)
	UIState.push("Payout", { hidePhone = true, hideWaypoints = true, lockControls = true })
	local card = gui.Payout.Card
	card.Title.Text = msg.title or ""
	local rows = card.Rows
	for _, c in rows:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local order = 0
	local function row(label: string, value: string, color: Color3?)
		order += 1
		local r = Build.payoutRow(label, value, color)
		r.LayoutOrder = order
		r.Parent = rows
	end
	row("Register take", Format.cash(msg.take or 0))
	if msg.clean then
		row("Clean getaway", "+" .. Format.cash(msg.bonus or 0), C.Gold)
	elseif msg.escape then
		row("Getaway time", MissionRules.clock(msg.escape) .. "  (under " .. MissionRules.clock(msg.cleanSeconds or 30) .. " = bonus)")
	end
	if (msg.mult or 1) > 1 then
		row("2x Money", "x" .. tostring(msg.mult), C.Accent)
	end
	card.XP.Text = if (msg.xp or 0) > 0 then ("+" .. tostring(msg.xp) .. " XP") else ""
	card.Note.Text = if msg.debug then "(Studio debug: reached by debugSet, nothing was paid)" else "Your crew's waiting on you. Spend it well."
	local total = if msg.debug then (msg.take or 0) + (msg.bonus or 0) else (msg.paid or 0)
	card.Total.Value.Text = "$0"
	showFull(gui.Payout)
	task.delay(0.35, function()
		Motion.count(card.Total.Value, 0, total, 1.4, Format.cash)
		for i = 1, 8 do
			task.delay(i * 0.16, sound, "Cash", 0.25)
		end
		task.delay(1.45, sound, "Done", 0.5)
	end)
end

---------------------------------------------------------------- per frame

local function frame()
	renderScene(meetScene)
	renderScene(missionScene)
	-- meet props appear once you're within range (the area is probably streamed in by then)
	if meet and not meetScene then
		local r = root()
		if r and (r.Position - meet.cframe.Position).Magnitude <= Missions.Meet.ShowPropsWithin then
			task.spawn(buildMeet)
		end
	end
	local state = current
	if not state then
		return
	end
	local st = state.step
	local hidden = UIState.get().hideHUD == true
	-- hold prompt
	local showPrompt = st.kind == "hold" and inRange(state) and not hidden
	gui.Prompt.Visible = showPrompt
	if holding then
		if not inRange(state, 3) then
			endHold()
		else
			local a = math.clamp((os.clock() - holdStart) / (st.seconds or 1), 0, 1)
			gui.Prompt.Bar.Fill.Size = UDim2.fromScale(a, 1)
			if a >= 1 and not holdSent then
				holdSent = true
				action("step", { step = st.id })
			end
		end
	end
	-- aim step
	local isAim = st.kind == "aim"
	local near = isAim and inRange(state, 14)
	gui.Meter.Visible = near and not hidden
	gui.AimButton.Visible = near and state.aimFallback and UserInputService.TouchEnabled and not hidden
	if isAim and not state.aimFallback then
		gui.Meter.Bar.Fill.Size = UDim2.fromScale(serverProgress, 1)
	elseif aiming then
		-- turn toward the clerk (light aim assist), fill while facing them
		local r = root()
		if r and state.clerk then
			local target = Vector3.new(state.clerk.X, r.Position.Y, state.clerk.Z)
			local camLook = camera.CFrame.LookVector
			local want = Vector3.new(camLook.X, 0, camLook.Z)
			local toClerk = (target - r.Position)
			if toClerk.Magnitude > 0.5 and want.Magnitude > 0.01 and want.Unit:Dot(toClerk.Unit) > 0.75 then
				want = toClerk -- snap to the clerk when roughly aiming at them
			end
			if want.Magnitude > 0.01 then
				r.CFrame = r.CFrame:Lerp(CFrame.lookAt(r.Position, r.Position + want), 0.25)
			end
		end
		if facingClerk() then
			if not aimStart then
				aimStart = os.clock()
				action("begin", { step = st.id })
			end
			local a = math.clamp((os.clock() - aimStart) / (st.seconds or 2), 0, 1)
			gui.Meter.Bar.Fill.Size = UDim2.fromScale(a, 1)
			if a >= 1 and not aimSent then
				aimSent = true
				action("step", { step = st.id })
			end
		else
			aimStart = nil
			aimSent = false
			gui.Meter.Bar.Fill.Size = UDim2.fromScale(0, 1)
		end
	end
	-- alarm pulse + clean-getaway timer
	if state.alarm and alarmStartedLocal then
		local pulse = 0.5 + 0.5 * math.sin(os.clock() * 7)
		for _, e in gui.Alarm:GetChildren() do
			if e:IsA("Frame") then
				e.BackgroundTransparency = 0.25 + 0.6 * (1 - pulse)
			end
		end
		if tillLight then
			tillLight.Brightness = 3 * pulse
		end
		local left = (state.cleanSeconds or 0) - (os.clock() - alarmStartedLocal)
		local timer = gui.Tracker.Body.Timer
		timer.Visible = state.cleanSeconds ~= nil
		if left > 0 then
			timer.Text = "Clean getaway  " .. MissionRules.clock(left)
			timer.TextColor3 = C.Gold
		else
			timer.Text = "Just get to the car!"
			timer.TextColor3 = C.TextDim
		end
	else
		gui.Tracker.Body.Timer.Visible = false
	end
end

---------------------------------------------------------------- init

function MissionController.state(): any
	return current
end

function MissionController.init()
	gui = getGui()

	Net.get("MissionState").OnClientEvent:Connect(function(msg)
		if type(msg) ~= "table" then
			return
		end
		local kind = msg.type
		if kind == "state" then
			onState(msg)
		elseif kind == "clear" then
			task.spawn(onClear)
		elseif kind == "bark" and type(msg.who) == "string" and type(msg.text) == "string" then
			bark(msg.who, msg.text)
		elseif kind == "progress" and type(msg.value) == "number" then
			serverProgress = math.clamp(msg.value, 0, 1)
		elseif kind == "meet" and typeof(msg.cframe) == "CFrame" then
			meet = { cframe = msg.cframe, label = msg.label or "" }
			clearMeet()
		elseif kind == "meetClear" then
			meet = nil
			clearMeet()
		elseif kind == "payout" then
			showPayout(msg)
		end
	end)

	-- the cutscene builds its own crew at the same spots: hide ours while it plays
	Cutscene.Started:Connect(function()
		if meetScene then
			meetScene.folder.Parent = nil
		end
		if missionScene then
			missionScene.folder.Parent = nil
		end
		endHold()
		stopAim()
	end)
	Cutscene.Finished:Connect(function()
		if meetScene then
			meetScene.folder.Parent = Actors.folder()
		end
		if missionScene then
			missionScene.folder.Parent = Actors.folder()
		end
	end)

	gui.Payout.Card.Continue.Activated:Connect(function()
		hideFull(gui.Payout)
		if payoutMsg then
			task.delay(0.15, showOffer, payoutMsg)
		else
			closeOffer()
		end
	end)
	gui.Offer.Card.Later.Activated:Connect(closeOffer)

	-- hold: keys, or press-and-hold the prompt (mouse/touch)
	UserInputService.InputBegan:Connect(function(input, processed)
		if HOLD_KEYS[input.KeyCode] and not processed then
			beginHold()
		elseif (AIM_INPUTS[input.UserInputType] or AIM_KEYS[input.KeyCode]) then
			startAim()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if HOLD_KEYS[input.KeyCode] then
			endHold()
		elseif AIM_INPUTS[input.UserInputType] or AIM_KEYS[input.KeyCode] then
			stopAim()
		end
	end)
	gui.Prompt.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			beginHold()
		end
	end)
	gui.Prompt.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			endHold()
		end
	end)
	gui.AimButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			startAim()
		end
	end)
	gui.AimButton.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			stopAim()
		end
	end)

	UIState.Changed:Connect(function(state)
		gui.Enabled = not (state.hideHUD and not UIState.has("Payout"))
	end)

	player.CharacterAdded:Connect(function()
		resetHold()
		aiming = false
	end)

	RunService.RenderStepped:Connect(function()
		local ok, err = pcall(frame)
		if not ok then
			warn("[MTL Mission] frame error:", err)
		end
	end)
end

return MissionController
