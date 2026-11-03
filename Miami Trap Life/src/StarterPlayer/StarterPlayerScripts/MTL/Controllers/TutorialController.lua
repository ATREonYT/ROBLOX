--!strict
-- The new-player coach (Research: Cinematic Cutscenes §9). Steps live in Config/Tutorial.lua, the order logic in
-- Rules/TutorialRules.lua. One card at a time, a pulsing ring around the REAL HUD/phone element it talks about
-- (found by name, so the HUD and phone redesigns keep working), and each step ends when the player does the thing.
-- Hidden during cutscenes and anything that hides the HUD. Progress is saved in Settings.Tutorial through the phone's
-- setSetting action (whitelisted in Config/Phone.SettingKeys), so a rejoin never repeats a finished step.
--   Tutorial.restart()   (Studio / Settings later: shows it again from step 1)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Net = require(ReplicatedStorage.MTL.Net)
local Theme = require(ReplicatedStorage.MTL.UI.Theme)
local Motion = require(ReplicatedStorage.MTL.UI.Motion)
local Story = require(ReplicatedStorage.MTL.Config.Story)
local Config = require(ReplicatedStorage.MTL.Config.Tutorial)
local TutorialRules = require(ReplicatedStorage.MTL.Rules.TutorialRules)
local Build = require(ReplicatedStorage.MTL.UI.Build.Tutorial)
local ClientData = require(script.Parent.ClientData)
local UIState = require(script.Parent.UIState)

local player = Players.LocalPlayer
local T = (Theme :: any).Tutorial
local Steps = Config.Steps

local Tutorial = {}

local function optional(name: string): any
	local m = script.Parent:FindFirstChild(name)
	if not m then
		return nil
	end
	local ok, mod = pcall(require, m)
	return if ok then mod else nil
end

local Sfx: any = nil
do
	local m = ReplicatedStorage.MTL.UI:FindFirstChild("Sfx")
	if m then
		local ok, mod = pcall(require, m)
		Sfx = if ok then mod else nil
	end
end
local function sound(name: string, volume: number?)
	if Sfx then
		pcall(Sfx.play, name, if volume then { volume = volume } else nil)
	end
end

local gui: any
local Phone: any, Menu: any, HUD: any, Cutscene: any
local localDone = 0 -- steps finished this session (the save catches up a moment later)
local shown: { index: number, step: any, at: number, phoneOpened: boolean, phoneOpenAt: number?, tasksAtStart: number }? = nil
local completing = false
local quietUntil = 0 -- no card before this (os.clock), e.g. right after a cutscene

local function device(): string
	local last = UserInputService:GetLastInputType()
	if last.Name:match("^Gamepad") then
		return "pad"
	elseif last == Enum.UserInputType.Touch then
		return "touch"
	elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "touch"
	elseif UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return "pad"
	end
	return "kb"
end

local function savedDone(): number
	local data = ClientData.get()
	local v = data and data.Settings and data.Settings.Tutorial
	return math.max(if type(v) == "number" then v else 0, localDone)
end

local function save(n: number)
	localDone = math.max(localDone, n)
	Net.get("PhoneAction"):FireServer({ type = "setSetting", key = "Tutorial", value = localDone })
end

local function tasksDone(): number
	local data = ClientData.get()
	local n = 0
	for _, c in (data and data.Job and data.Job.TasksDone) or {} do
		if type(c) == "number" then
			n += c
		end
	end
	return n
end

---------------------------------------------------------------- the ring around a HUD element

local onScreen: (GuiObject) -> boolean

-- "**Name": any descendant with that name; when there are several (e.g. a hidden grid copy and the dock icon),
-- the one actually on screen wins
local function deepFind(root: Instance, name: string): Instance?
	local first: Instance? = nil
	for _, d in root:GetDescendants() do
		if d.Name == name then
			if d:IsA("GuiObject") and onScreen(d) then
				return d
			end
			first = first or d
		end
	end
	return first
end

local function findTarget(id: string?): GuiObject?
	local paths = id and (Config.Targets :: any)[id]
	if not paths then
		return nil
	end
	local pg = player:FindFirstChild("PlayerGui")
	for _, path in paths do
		local node: Instance? = pg
		for _, name in path do
			if node and string.sub(name, 1, 2) == "**" then
				node = deepFind(node, string.sub(name, 3))
			else
				node = node and node:FindFirstChild(name)
			end
		end
		if node and node:IsA("GuiObject") then
			return node
		end
	end
	return nil
end

function onScreen(obj: GuiObject): boolean
	local node: Instance? = obj
	while node and node:IsA("GuiObject") do
		if not node.Visible then
			return false
		end
		node = node.Parent
	end
	local sg = obj:FindFirstAncestorOfClass("ScreenGui")
	return sg ~= nil and sg.Enabled and obj.AbsoluteSize.X > 2
end

local function placeRing(now: number)
	local ring, arrow = gui.Ring, gui.Arrow
	local id = shown and shown.step.target
	if shown and shown.step.whileOpenTarget and Phone and Phone.isOpen and Phone.isOpen() then
		id = shown.step.whileOpenTarget
	end
	local target = shown and gui.Card.Visible and findTarget(id)
	if not target or not onScreen(target) then
		ring.Visible = false
		arrow.Visible = false
		return
	end
	-- Screen position of the target in OUR ScreenGui's space. AbsolutePosition is already in one shared screen space
	-- for every ScreenGui (a top-bar-inset gui just has a non-zero origin), so the ring's offset is simply the target's
	-- AbsolutePosition minus OUR gui's own AbsolutePosition. (The old version added the target gui's origin as
	-- well, which put the ring one top-bar height off: Alex, 2026-11-03, "the outlines sit above the thing".)
	-- Rotated parents (the phone is tilted a few degrees) move the target's centre: rotate it around each one too.
	local origin = -(gui :: any).AbsolutePosition
	local pad = 5 -- hug the element: a ring this close reads as an outline, not a box around it
	local center = target.AbsolutePosition + target.AbsoluteSize / 2
	local rot = target.Rotation
	local node: Instance? = target.Parent
	while node and node:IsA("GuiObject") do
		if node.Rotation ~= 0 then
			local c = node.AbsolutePosition + node.AbsoluteSize / 2
			local a = math.rad(node.Rotation)
			local d = center - c
			center = c + Vector2.new(d.X * math.cos(a) - d.Y * math.sin(a), d.X * math.sin(a) + d.Y * math.cos(a))
			rot += node.Rotation
		end
		node = node.Parent
	end
	center += origin
	local size = target.AbsoluteSize + Vector2.new(pad * 2, pad * 2)
	local pos = center - size / 2
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromOffset(center.X, center.Y)
	ring.Size = UDim2.fromOffset(size.X, size.Y)
	ring.Rotation = rot
	-- the ring takes the element's own corner shape (a round button gets a round ring, the phone a phone shape)
	local rc = ring:FindFirstChildOfClass("UICorner")
	if rc then
		local tc = target:FindFirstChildOfClass("UICorner")
		rc.CornerRadius = if tc then UDim.new(tc.CornerRadius.Scale, tc.CornerRadius.Offset + pad) else UDim.new(0, 8)
	end
	local pulse = (math.sin(now * math.pi * 2 * 0.7) + 1) / 2 -- same breathing as every outline (UI/Guide)
	ring.Stroke.Transparency = 0.1 + pulse * 0.45
	ring.Stroke.Thickness = 2 + pulse * 1
	ring.Visible = true
	-- arrow: above the ring, or below it when the element sits at the top of the screen
	local cam = workspace.CurrentCamera
	local screenH = if cam then cam.ViewportSize.Y else 800
	local above = pos.Y > 70
	local bob = math.sin(now * math.pi * 2 * 0.7) * 3
	arrow.Text = if above then "▼" else "▲"
	arrow.Position = UDim2.fromOffset(pos.X + size.X / 2, if above then pos.Y - 20 + bob else math.min(pos.Y + size.Y + 20 - bob, screenH - 20))
	arrow.Visible = true
end

---------------------------------------------------------------- the card

local function setDots(index: number)
	local dots = gui.Card.Bottom.Dots
	for _, d in dots:GetChildren() do
		if d:IsA("Frame") and d.Name ~= "DotTemplate" then
			d:Destroy()
		end
	end
	for i = 1, #Steps do
		local d = dots.DotTemplate:Clone()
		d.Name = "Dot" .. i
		d.LayoutOrder = i
		d.Visible = true
		d.BackgroundColor3 = if i <= index then T.Accent else T.Dim
		d.BackgroundTransparency = if i <= index then 0 else 0.5
		d.Size = if i == index then UDim2.fromOffset(18, 8) else UDim2.fromOffset(8, 8)
		d.Parent = dots
	end
end

local shownKeys = ""
local function setKeys(list: { string })
	local sig = table.concat(list, "|")
	if sig == shownKeys then
		return -- unchanged: don't rebuild the chips every refresh (they flickered)
	end
	shownKeys = sig
	local keys = gui.Card.Keys
	for _, k in keys:GetChildren() do
		if k:IsA("Frame") and k.Name ~= "KeyTemplate" then
			k:Destroy()
		end
	end
	for i, text in list do
		local k = keys.KeyTemplate:Clone()
		k.Name = "Key" .. i
		k.LayoutOrder = i
		k.Label.Text = text
		k.Visible = true
		k.Parent = keys
	end
	keys.Visible = #list > 0
end

local function fillCard()
	if not shown then
		return
	end
	local step, dev = shown.step, device()
	local card = gui.Card
	card.Step.Text = string.format("STEP %d OF %d", shown.index, #Steps)
	card.Title.Text = step.title
	local phoneOpen = Phone and Phone.isOpen and Phone.isOpen()
	local body = if step.done == "phone" and phoneOpen and step.whileOpen then step.whileOpen else step.body
	local text = TutorialRules.text(body, dev)
	if step.liveTask then
		-- say exactly what the job panel wants right now ("Now: Stock the empty shelf")
		local pg = player:FindFirstChild("PlayerGui")
		local panel = pg and pg:FindFirstChild("MTL_Job") and pg.MTL_Job:FindFirstChild("Panel")
		local label = panel and panel:FindFirstChild("Body") and panel.Body:FindFirstChild("Task")
		if label and label:IsA("TextLabel") and label.Text ~= "" then
			text = "Now: " .. label.Text .. ". " .. TutorialRules.text(step.liveTask, dev)
		end
	end
	-- {call} = the level the unknown number calls at for this player (Config/Levels.CallLevelTest)
	local call = player:GetAttribute("MTL_CallLevel")
	text = string.gsub(text, "{call}", tostring(if type(call) == "number" then call else 4))
	card.Body.Text = text
	setKeys(if step.done == "phone" and phoneOpen then {} else TutorialRules.keys(step, dev))
	card.Bottom.Ok.Visible = step.ok ~= nil
	card.Bottom.Ok.Text = step.ok or "Got it"
	setDots(shown.index)
end

local function showCard(index: number, step: any)
	shown = { index = index, step = step, at = os.clock(), phoneOpened = false, phoneOpenAt = nil, tasksAtStart = tasksDone() }
	local card = gui.Card
	card.Tick.Visible = false
	fillCard()
	card.Visible = true
	card.Pop.Scale = 0.92
	Motion.tween(card.Pop, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
	sound("Open", 0.3)
end

local function hideCard()
	gui.Card.Visible = false
	gui.Ring.Visible = false
	gui.Arrow.Visible = false
end

local function complete()
	local s = shown
	if not s or completing then
		return
	end
	completing = true
	save(s.index)
	sound("Confirm", 0.4)
	local tick = gui.Card.Tick
	tick.Visible = true
	tick.Pop.Scale = 0.4
	Motion.tween(tick.Pop, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
	task.delay(Config.Tuning.BetweenSteps, function()
		shown = nil
		completing = false
		hideCard()
		quietUntil = os.clock() + 0.3
		if TutorialRules.finished(Steps, savedDone()) and savedDone() < Config.Skipped then
			if HUD and HUD.toast then
				pcall(HUD.toast, Config.Tuning.DoneToast, T.Accent)
			end
		end
	end)
end

local function stepDone(s: any): boolean
	local step = s.step
	local now = os.clock()
	if step.seconds and now - s.at >= step.seconds then
		return true
	end
	if step.done == "phone" then
		local open = Phone and Phone.isOpen and Phone.isOpen()
		if open and not s.phoneOpened then
			s.phoneOpened = true
			s.phoneOpenAt = now
			fillCard()
		end
		if s.phoneOpened and (not open or now - (s.phoneOpenAt :: number) >= Config.Tuning.PhoneReadSeconds) then
			return true
		end
	elseif step.done == "task" then
		return tasksDone() > s.tasksAtStart
	elseif step.done == "starterBuy" then
		local data = ClientData.get()
		local st = data and data.Inventory and data.Inventory.Items and data.Inventory.Items.Starter
		return st ~= nil and st.Owned ~= nil and next(st.Owned) ~= nil
	elseif step.done == "menu" then
		return Menu ~= nil and Menu.isOpen ~= nil and Menu.isOpen()
	end
	return false
end

---------------------------------------------------------------- main loop

local function blocked(): boolean
	if Cutscene and Cutscene.isPlaying and Cutscene.isPlaying() then
		quietUntil = math.max(quietUntil, os.clock() + Config.Tuning.FirstDelay)
		return true
	end
	-- the HUD's own popups (Store, Emotes) win: never cover them
	local pg = player:FindFirstChild("PlayerGui")
	local panels = pg and pg:FindFirstChild("MTL_HUD") and pg.MTL_HUD:FindFirstChild("Panels")
	if panels then
		for _, p in panels:GetChildren() do
			if p:IsA("GuiObject") and p.Visible then
				quietUntil = math.max(quietUntil, os.clock() + 0.4)
				return true
			end
		end
	end
	-- an incoming / active call owns the phone screen: the ring and arrow would land on Answer / Decline
	local phoneGui = pg and pg:FindFirstChild("MTL_Phone")
	local callScreen = phoneGui and deepFind(phoneGui, "Call")
	if callScreen and callScreen:IsA("GuiObject") and callScreen.Visible then
		quietUntil = math.max(quietUntil, os.clock() + 0.6)
		return true
	end
	local st = UIState.get()
	if st.hideHUD then
		quietUntil = math.max(quietUntil, os.clock() + 0.6)
		return true
	end
	return os.clock() < quietUntil
end

local function tick()
	local data = ClientData.get()
	if not data then
		return
	end
	local stage = data.Story and data.Story.Stage
	local done = savedDone()
	-- cutscenes, fades and HUD popups always win (even over a step's tick)
	if blocked() then
		if gui.Card.Visible then
			hideCard()
		end
		return
	end
	if TutorialRules.finished(Steps, done) then
		if shown and not completing then
			shown = nil
			hideCard()
		end
		return
	end
	-- steps whose moment has passed (e.g. "Walk" once you're in the store) count as done
	local passed = TutorialRules.passed(Steps, done, stage, Story.Stages)
	if passed > done and not completing then
		if shown and shown.index <= passed then
			complete() -- the tick shows for a step the player just finished by moving the story on
			return
		end
		save(passed)
		done = passed
	end
	if completing then
		return
	end
	local index, step = TutorialRules.current(Steps, done, stage, Story.Stages)
	if not index then
		if shown then
			shown = nil
			hideCard()
		end
		return
	end
	if not shown or shown.index ~= index then
		showCard(index :: number, step)
	elseif not gui.Card.Visible then
		gui.Card.Visible = true -- back after a cutscene / menu hid it
		fillCard()
	elseif shown.step.liveTask then
		fillCard()
	end
	if shown and stepDone(shown) then
		complete()
	end
end

function Tutorial.restart()
	localDone = 0
	Net.get("PhoneAction"):FireServer({ type = "setSetting", key = "Tutorial", value = 0 })
	shown = nil
	hideCard()
end

function Tutorial.init()
	local pg = player:WaitForChild("PlayerGui")
	gui = pg:FindFirstChild("MTL_Tutorial")
	if not gui then
		gui = Build.build()
		gui.Parent = pg
	end
	gui.Card.Visible = false
	gui.Ring.Visible = false
	gui.Arrow.Visible = false
	Phone = optional("PhoneController")
	Menu = optional("MenuController")
	HUD = optional("HUDController")
	Cutscene = optional("CutsceneController")
	quietUntil = os.clock() + Config.Tuning.FirstDelay

	gui.Card.Bottom.Ok.Activated:Connect(function()
		if shown and shown.step.ok then
			complete()
		end
	end)
	gui.Card.Bottom.Skip.Activated:Connect(function()
		sound("Tap", 0.4)
		localDone = Config.Skipped
		Net.get("PhoneAction"):FireServer({ type = "setSetting", key = "Tutorial", value = Config.Skipped })
		shown = nil
		hideCard()
		if HUD and HUD.toast then
			pcall(HUD.toast, "Tutorial skipped. Your goal is always at the top.", T.Dim)
		end
	end)
	-- a cutscene hides the card at once (not on the next tick, or it shows through the fade-in)
	if Cutscene and Cutscene.Started then
		Cutscene.Started:Connect(function()
			quietUntil = math.max(quietUntil, os.clock() + Config.Tuning.FirstDelay)
			hideCard()
		end)
	end
	if Phone and Phone.Opened then
		Phone.Opened:Connect(fillCard)
		Phone.Closed:Connect(fillCard)
	end
	UserInputService.LastInputTypeChanged:Connect(function()
		if shown then
			fillCard()
		end
	end)

	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		placeRing(os.clock())
		acc += dt
		if acc >= 0.2 then
			acc = 0
			local ok, err = pcall(tick)
			if not ok then
				warn("[MTL Tutorial]", err)
			end
		end
	end)
	print("[MTL Tutorial] ready")
end

return Tutorial
